#import <Common.h>
#import <Foundation/Foundation.h>
#import <snudown/snudown.h>

static BOOL enabled;
static BOOL slideEnabled;
static BOOL highlight;
static BOOL useIDs;

typedef void (^DataTaskCompletionBlock)(NSData *data, NSURLResponse *response, NSError *error);

static BOOL shouldUndelete(NSArray *comments) {
    for (NSDictionary *outerComment in comments) {
        if ([outerComment[@"kind"] isEqualToString:@"more"]) continue;
        NSMutableDictionary *comment = outerComment[@"data"];
        if (isDeleted(comment[@"body"])) {
            return YES;
        } else {
            if ([comment[@"replies"] isKindOfClass:[NSDictionary class]] &&
                shouldUndelete(comment[@"replies"][@"data"][@"children"])) {
                return YES;
            }
        }
    }

    return NO;
}

static void flattenTree(NSArray *comments, NSMutableDictionary *dictionary) {
    for (NSDictionary *outerComment in comments) {
        if ([outerComment[@"kind"] isEqualToString:@"more"]) continue;
        NSMutableDictionary *comment = outerComment[@"data"];

        if (isDeleted(comment[@"body"])) {
            dictionary[comment[@"id"]] = comment;
        }

        if ([comment[@"replies"] isKindOfClass:[NSDictionary class]]) {
            flattenTree(comment[@"replies"][@"data"][@"children"], dictionary);
        }
    }
}

static void undeleteComments(NSString *ident, NSArray *comments) {
    NSMutableDictionary *deletedComments = [NSMutableDictionary dictionary];
    flattenTree(comments, deletedComments);

    if (deletedComments.count > 0) {
        NSLog(@"Attempting to undelete %lu comments...", (unsigned long)deletedComments.count);

        // now get the values and sort them by ascending date
        NSArray<NSDictionary *> *dates = [deletedComments.allValues
            sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
                return [a[@"created_utc"] compare:b[@"created_utc"]];
            }];

        NSArray *pushshiftComments = getPushshiftCommentsForArray(ident, dates, CommentRaw, useIDs);
        NSLog(@"Got %d comments from pushshift", (int)pushshiftComments.count);
        int undeleteCount = 0;

        for (NSDictionary *psComment in pushshiftComments) {
            if (deletedComments[psComment[@"id"]] && !isDeleted(psComment[@"body"])) {
                NSLog(@"Undeleting %@", psComment[@"id"]);
                NSMutableDictionary *comment = deletedComments[psComment[@"id"]];

                comment[@"author_flair_text"] = comment[@"body"];
                comment[@"body_html"] = markdownToHTML(psComment[@"body"]);
                comment[@"author"] = psComment[@"author"];
                if (highlight) comment[@"distinguished"] = @"special";
                undeleteCount++;
            }
        }

        NSLog(@"Undeleted %d comments out of %lu", undeleteCount, (unsigned long)deletedComments.count);
    }
}

static void undeletePost(NSString *ident, NSMutableDictionary *link) {
    NSLog(@"Attempting to undelete post...");
    NSDictionary *post = getPushshiftPost(ident);

    if (post) {
        link[@"author_flair_text"] = link[@"selftext"];
        link[@"selftext_html"] = markdownToHTML(post[@"selftext"]);
        link[@"author"] = post[@"author"];
        link[@"title"] = post[@"title"];
        if (highlight) link[@"distinguished"] = @"special";
    }
}

%group Slide
%hook NSURLSession

// i'd rather hook higher up but almost the entire slide app is written in swift :(

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
                            completionHandler:(DataTaskCompletionBlock)completionHandler {
    DataTaskCompletionBlock c2 = ^(NSData *data, NSURLResponse *response, NSError *error) {
        if (enabled && slideEnabled && [request.URL.host isEqualToString:@"oauth.reddit.com"]) {
            if ([request.URL.path containsString:@"/comments/"] && [request.URL.path containsString:@".json"]) {
                NSArray *jsonData = [NSJSONSerialization JSONObjectWithData:data
                                                                    options:NSJSONReadingMutableContainers
                                                                      error:nil];
                if (jsonData && jsonData.count >= 2) {
                    NSString *ident = jsonData[0][@"data"][@"children"][0][@"data"][@"id"];
                    NSArray *comments = jsonData[1][@"data"][@"children"];
                    NSMutableDictionary *post = jsonData[0][@"data"][@"children"][0][@"data"];

                    if (ident && comments && post) {
                        if (shouldUndelete(comments)) undeleteComments(ident, comments);
                        if (isDeleted(post[@"selftext"])) undeletePost(ident, post);

                        completionHandler([NSJSONSerialization dataWithJSONObject:jsonData
                                                                          options:0
                                                                            error:nil],
                                          response, error);

                        return;
                    }
                }
            } else if ([request.URL.path containsString:@"/morechildren.json"]) {
                NSMutableDictionary *jsonData = [NSJSONSerialization JSONObjectWithData:data
                                                                                options:NSJSONReadingMutableContainers
                                                                                  error:nil];
                if (jsonData) {
                    NSString *body = [[NSString alloc] initWithData:request.HTTPBody
                                                           encoding:NSUTF8StringEncoding];
                    NSRegularExpression *regex = [NSRegularExpression
                        regularExpressionWithPattern:@"link_id=(.+?)&"
                                             options:NSRegularExpressionCaseInsensitive
                                               error:nil];
                    NSTextCheckingResult *match =
                        [regex firstMatchInString:body options:0 range:NSMakeRange(0, body.length)];

                    if (match) {
                        NSString *ident = [body substringWithRange:[match rangeAtIndex:1]];
                        NSArray *comments = jsonData[@"json"][@"data"][@"things"];

                        if (ident && comments) {
                            if (shouldUndelete(comments)) undeleteComments(ident, comments);

                            completionHandler([NSJSONSerialization dataWithJSONObject:jsonData
                                                                              options:0
                                                                                error:nil],
                                              response, error);
                            return;
                        }
                    }
                }
            }
        }
        completionHandler(data, response, error);
    };

    return %orig(request, c2);
}

%end
%end

static void loadPrefs() {
    NSMutableDictionary *settings = [[NSMutableDictionary alloc]
        initWithContentsOfFile:@"/var/mobile/Library/Preferences/xyz.hgrunt.autoundelete.plist"];

    enabled = getBool(settings, @"isEnabled");
    slideEnabled = getBool(settings, @"isSlideEnabled");
    highlight = getBool(settings, @"shouldHighlight");
    useIDs = getBool(settings, @"useIDs");
}

%ctor {
    loadPrefs();
    if ([NSProcessInfo.processInfo.processName isEqualToString:@"Slide for Reddit"] && enabled && slideEnabled) {
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)loadPrefs,
            (CFStringRef) @"xyz.hgrunt.autoundelete/preferences.changed", NULL,
            CFNotificationSuspensionBehaviorCoalesce);
        initsnudown();
        %init(Slide);
    }
}
