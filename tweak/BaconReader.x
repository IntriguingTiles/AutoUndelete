#import <Common.h>
#import <Foundation/Foundation.h>
#import <snudown/snudown.h>

static BOOL enabled;
static BOOL baconReaderEnabled;
static BOOL highlight;
static BOOL useIDs;

typedef void (^AFSuccessCompletionBlock)(NSURLSessionDataTask *dataTask, id response);
typedef void (^AFFailureCompletionBlock)(NSURLSessionDataTask *dataTask, NSError *error);

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
                comment[@"body"] = psComment[@"body"];
                comment[@"body_html"] = markdownToHTML(psComment[@"body"]);
                comment[@"author"] = psComment[@"author"];
                // baconreader doesn't distinguish comments for some reason :(
                // if (highlight) comment[@"distinguished"] = @"special";
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
        link[@"title"] = post[@"title"];
        link[@"url"] = post[@"url"];
        link[@"selftext"] = post[@"selftext"];
        link[@"selftext_html"] = markdownToHTML(post[@"selftext"]);
        link[@"author"] = post[@"author"];
        // if (highlight) link[@"distinguished"] = @"special";
    }
}

%group BaconReader
%hook AFHTTPSessionManager

- (NSURLSessionDataTask *)GET:(NSString *)URLString
                   parameters:(id)parameters
                      headers:(NSDictionary<NSString *, NSString *> *)headers
                     progress:(void (^)(NSProgress *_Nonnull))downloadProgress
                      success:(AFSuccessCompletionBlock)success
                      failure:(AFFailureCompletionBlock)failure {
    AFSuccessCompletionBlock c2 = ^(NSURLSessionDataTask *dataTask, NSArray *response) {
        if (enabled && baconReaderEnabled) {
            if ([URLString containsString:@"/comments/"] && [URLString containsString:@".json"] &&
                response && response.count >= 2) {
                // cheating to make the response mutable without making every response mutable
                NSData *json = [NSJSONSerialization dataWithJSONObject:response
                                                               options:0
                                                                 error:nil];
                response = [NSJSONSerialization JSONObjectWithData:json
                                                           options:NSJSONReadingMutableContainers
                                                             error:nil];
                NSString *ident = response[0][@"data"][@"children"][0][@"data"][@"id"];
                NSArray *comments = response[1][@"data"][@"children"];
                NSMutableDictionary *post = response[0][@"data"][@"children"][0][@"data"];

                if (ident && comments && post) {
                    if (shouldUndelete(comments)) undeleteComments(ident, comments);
                    if (isDeleted(post[@"selftext"])) undeletePost(ident, post);
                }
            }
        }
        success(dataTask, response);
    };

    AFFailureCompletionBlock c3 = ^(NSURLSessionDataTask *dataTask, NSError *error) {
        NSData *data = error.userInfo[@"com.alamofire.serialization.response.error.data"];

        if (data && enabled && baconReaderEnabled) {
            // decode data
            NSDictionary *info = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if ([URLString containsString:@"/about.json"]) {
                if (info && info[@"reason"] && [info[@"reason"] isEqualToString:@"banned"]) {
                    // fake info and call success
                    success(
                        dataTask, @{
                            @"data" : @{
                                @"id" : @"notarealid",
                                @"display_name" : [URLString
                                    substringWithRange:NSMakeRange(3, URLString.length - 3 - 11)],
                                @"url" : [URLString substringWithRange:NSMakeRange(0, URLString.length - 10)]
                            }
                        });
                    return;
                }
            } else if ([URLString containsString:@"/r/"] && [URLString containsString:@".json"]) {
                // likely fetching posts
                if (info && info[@"reason"] && [info[@"reason"] isEqualToString:@"banned"]) {
                    NSArray *data =
                        getPushshiftPostsForSubreddit([URLString componentsSeparatedByString:@"/"][2]);
                    NSMutableArray *posts = [NSMutableArray array];
                    if (data.count > 0) {
                        NSDictionary *banInfo =
                            getSubredditBanInfo([URLString componentsSeparatedByString:@"/"][2], NO);

                        [posts addObject:@{
                            @"kind" : @"t3",
                            @"data" : @{
                                @"likes" : [NSNull null],
                                @"archived" : @YES,
                                @"stickied" : @YES,
                                @"is_self" : @YES,
                                @"title" : @"[banned subreddit]",
                                @"author" : @"[AutoUndelete]",
                                @"created_utc" : banInfo[@"timestamp"],
                                @"selftext" : banInfo[@"reason"],
                                @"selftext_html" : markdownToHTML(banInfo[@"reason"]),
                                @"id" : @"notarealid",
                                @"name" : @"t3_notarealid"
                            }
                        }];

                        for (NSMutableDictionary *psPost in data) {
                            psPost[@"likes"] = [NSNull null];
                            psPost[@"archived"] = @YES;
                            psPost[@"name"] = [NSString stringWithFormat:@"t3_%@", psPost[@"id"]];
                            if ([psPost[@"selftext"] length] > 0)
                                psPost[@"selftext_html"] = markdownToHTML(psPost[@"selftext"]);

                            [posts addObject:@{@"kind" : @"t3", @"data" : psPost}];
                        };

                        success(
                            dataTask, @{
                                @"kind" : @"Listing",
                                @"data" : @{
                                    @"after" : [posts lastObject][@"data"][@"name"],
                                    @"dist" : @26,
                                    @"modhash" : @"",
                                    @"geo_filter" : [NSNull null],
                                    @"children" : posts,
                                    @"before" : [NSNull null]
                                }
                            });
                        return;
                    }
                }
            }
        }

        failure(dataTask, error);
    };

    return %orig(URLString, parameters, headers, downloadProgress, c2, c3);
}

- (NSURLSessionDataTask *)POST:(NSString *)URLString
                    parameters:(id)parameters
                       headers:(NSDictionary<NSString *, NSString *> *)headers
                      progress:(void (^)(NSProgress *uploadProgress))uploadProgress
                       success:(AFSuccessCompletionBlock)success
                       failure:(void (^)(NSURLSessionDataTask *_Nullable task, NSError *error))failure {
    AFSuccessCompletionBlock c2 = ^(NSURLSessionDataTask *dataTask, NSDictionary *response) {
        if (enabled && baconReaderEnabled && [URLString containsString:@"morechildren.json"]) {
            NSData *json = [NSJSONSerialization dataWithJSONObject:response options:0 error:nil];
            response = [NSJSONSerialization JSONObjectWithData:json
                                                       options:NSJSONReadingMutableContainers
                                                         error:nil];
            NSString *ident = parameters[@"link_id"];
            NSArray *comments = response[@"json"][@"data"][@"things"];

            if (ident && comments) {
                if (shouldUndelete(comments)) undeleteComments(ident, comments);
            }
        }
        success(dataTask, response);
    };

    return %orig(URLString, parameters, headers, uploadProgress, c2, failure);
}

%end
%end

static void loadPrefs() {
    NSMutableDictionary *settings = [[NSMutableDictionary alloc]
        initWithContentsOfFile:@"/var/mobile/Library/Preferences/xyz.hgrunt.autoundelete.plist"];

    enabled = getBool(settings, @"isEnabled");
    baconReaderEnabled = getBool(settings, @"isBaconReaderEnabled");
    highlight = getBool(settings, @"shouldHighlight");
    useIDs = getBool(settings, @"useIDs");
}

%ctor {
    loadPrefs();
    if ([NSProcessInfo.processInfo.processName isEqualToString:@"BaconReader"] && enabled && baconReaderEnabled) {
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)loadPrefs,
            (CFStringRef) @"xyz.hgrunt.autoundelete/preferences.changed", NULL,
            CFNotificationSuspensionBehaviorCoalesce);
        initsnudown();
        %init(BaconReader);
    }
}
