#import <Common.h>
#import <Foundation/Foundation.h>

static BOOL enabled;
static BOOL redditEnabled;
static BOOL highlight;
static BOOL useIDs;

typedef void (^DataTaskCompletionBlock)(NSData *data, NSURLResponse *response, NSError *error);

static NSDictionary *markdownToRTJSON(NSString *markdown, NSString *auth) {
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    NSMutableCharacterSet *chars = NSCharacterSet.URLQueryAllowedCharacterSet.mutableCopy;
    [chars removeCharactersInString:@"@$&+=;:,/"];
    [request
        setURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://oauth.reddit.com/api/"
                                                               @"convert_rte_body_format?output_"
                                                               @"mode=rtjson&markdown_text=%@",
                                                               [markdown stringByAddingPercentEncodingWithAllowedCharacters:chars]]]];
    [request setHTTPMethod:@"POST"];
    [request setValue:auth forHTTPHeaderField:@"Authorization"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"ios:xyz.hgrunt.autoundelete:v0.0.1 (by /u/IntriguingTies)"
        forHTTPHeaderField:@"User-Agent"];

    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    __block NSDictionary *result = nil;
    NSURLSessionDataTask *dataTask = [NSURLSession.sharedSession
        dataTaskWithRequest:request
          completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
              if (data) {
                  id jsonData = [NSJSONSerialization JSONObjectWithData:data options:0
                                                                  error:nil][@"output"];

                  if (jsonData) {
                      result = jsonData;
                      dispatch_semaphore_signal(semaphore);
                      return;
                  }
              }
              // no data :(
              dispatch_semaphore_signal(semaphore);
          }];

    [dataTask resume];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    return result;
}

static void undeleteComments(NSString *ident, NSString *auth, NSArray *comments) {
    NSMutableDictionary *deletedComments = [NSMutableDictionary dictionary];

    for (NSDictionary *outerComment in comments) {
        if ([outerComment[@"kind"] isEqualToString:@"more"]) continue;
        NSMutableDictionary *comment = outerComment[@"data"];

        if (isDeleted(comment[@"body"])) {
            deletedComments[comment[@"id"]] = comment;
        }
    }

    if (deletedComments.count > 0) {
        NSLog(@"Attempting to undelete %lu comments...", (unsigned long)deletedComments.count);

        // now get the values and sort them by ascending date
        NSArray<NSDictionary *> *dates = [deletedComments.allValues
            sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
                return [a[@"created_utc"] compare:b[@"created_utc"]];
            }];

        NSArray *pushshiftComments = getPushshiftCommentsForArray(ident, dates, CommentRaw, useIDs);
        NSLog(@"Got %d comments from pushshift", (int)[pushshiftComments count]);
        int undeleteCount = 0;

        for (NSDictionary *psComment in pushshiftComments) {
            if (deletedComments[psComment[@"id"]] && !isDeleted(psComment[@"body"])) {
                NSLog(@"Undeleting %@", psComment[@"id"]);
                NSMutableDictionary *comment = deletedComments[psComment[@"id"]];
                NSDictionary *rtjson = markdownToRTJSON(psComment[@"body"], auth);

                if (!rtjson) {
                    // couldn't use reddit's api for some reason?
                    NSLog(@"Couldn't use RTJSON API!");
                    rtjson = @{
                        @"document" : @[ @{
                            @"c" : @[ @{@"e" : @"text", @"t" : psComment[@"body"]} ],
                            @"e" : @"par"
                        } ]
                    };
                }

                comment[@"rtjson"] = rtjson;
                comment[@"author"] = psComment[@"author"];
                comment[@"author_flair_text"] = comment[@"body"];
                comment[@"collapsed"] = false;
                // mark undeleted comments as "admin" because the reddit app no longer shows "special"
                if (highlight) comment[@"distinguished"] = @"admin";
                undeleteCount++;
            }
        }

        NSLog(@"Undeleted %d comments out of %lu", undeleteCount, (unsigned long)deletedComments.count);
    }
}

static void undeletePost(NSString *ident, NSString *auth, NSMutableDictionary *link) {
    NSLog(@"Attempting to undelete post...");
    NSDictionary *post = getPushshiftPost(ident);

    if (post) {
        NSDictionary *rtjson = markdownToRTJSON(post[@"selftext"], auth);

        if (!rtjson) {
            // couldn't use reddit's api for some reason?
            NSLog(@"Couldn't use RTJSON API!");
            rtjson = @{
                @"document" : @[
                    @{@"c" : @[ @{@"e" : @"text", @"t" : post[@"selftext"]} ],
                      @"e" : @"par"}
                ]
            };
        }

        link[@"rtjson"] = rtjson;
        link[@"author"] = post[@"author"];
        link[@"author_flair_text"] = link[@"selftext"];
        if (highlight) link[@"distinguished"] = @"admin";
    }
}

%group Reddit
%hook NSURLSession

// i'd rather hook higher up but a lot of the reddit app is written in swift :(

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
                            completionHandler:(DataTaskCompletionBlock)completionHandler {
    DataTaskCompletionBlock c2 = ^(NSData *data, NSURLResponse *response, NSError *error) {
        if (enabled && redditEnabled && [request.URL.host isEqualToString:@"oauth.reddit.com"]) {
            if ([request.URL.path containsString:@"/comments/"] && [request.URL.path containsString:@".json"] &&
                ![request.URL.query containsString:@"truncate"]) {
                NSArray *jsonData = [NSJSONSerialization JSONObjectWithData:data
                                                                    options:NSJSONReadingMutableContainers
                                                                      error:nil];
                if (jsonData && jsonData.count >= 2) {
                    NSString *ident = jsonData[0][@"data"][@"children"][0][@"data"][@"id"];
                    NSArray *comments = jsonData[1][@"data"][@"children"];
                    NSMutableDictionary *post = jsonData[0][@"data"][@"children"][0][@"data"];

                    if (ident && comments && post) {
                        // need an auth token to convert markdown to rtjson (silly!)
                        NSString *auth = [request valueForHTTPHeaderField:@"Authorization"];
                        undeleteComments(ident, auth, comments);
                        if (isDeleted(post[@"selftext"])) undeletePost(ident, auth, post);

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
                    NSTextCheckingResult *match = [regex firstMatchInString:body
                                                                    options:0
                                                                      range:NSMakeRange(0, [body length])];

                    if (match) {
                        NSString *ident = [body substringWithRange:[match rangeAtIndex:1]];
                        NSArray *comments = jsonData[@"json"][@"data"][@"things"];

                        if (ident && comments) {
                            // need an auth token to convert markdown to rtjson (silly!)
                            NSString *auth = [request valueForHTTPHeaderField:@"Authorization"];
                            undeleteComments(ident, auth, comments);

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
    redditEnabled = getBool(settings, @"isRedditEnabled");
    highlight = getBool(settings, @"shouldHighlight");
    useIDs = getBool(settings, @"useIDs");
}

%ctor {
    loadPrefs();
    if ([NSProcessInfo.processInfo.processName isEqualToString:@"RedditApp"] && enabled && redditEnabled) {
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)loadPrefs,
            (CFStringRef) @"xyz.hgrunt.autoundelete/preferences.changed", NULL,
            CFNotificationSuspensionBehaviorCoalesce);
        %init(Reddit);
    }
}
