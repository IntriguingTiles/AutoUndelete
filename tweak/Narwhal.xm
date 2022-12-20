#import <Common.h>
#import <Foundation/Foundation.h>
#import <headers/Narwhal/MTLJSONAdapter.h>
#import <headers/Narwhal/RKComment.h>
#import <headers/Narwhal/RKLink.h>
#import "substrate.h"

static BOOL enabled;
static BOOL narwhalEnabled;
static BOOL highlight;
static BOOL useIDs;

typedef void (^RKDictionaryCompletionBlock)(NSDictionary *collection, NSError *error);
typedef void (^RKObjectCompletionBlock)(id object, NSError *error);
typedef void (^RKArrayCompletionBlock)(NSArray *collection, NSError *error);
typedef void (^RKListingCompletionBlock)(NSArray *collection, id pagination, NSError *error);

static BOOL shouldUndelete(NSArray *comments) {
    for (RKComment *comment in comments) {
        if (![comment respondsToSelector:@selector(body)]) continue;
        if (isDeleted(comment.body)) {
            return YES;
        } else {
            if (shouldUndelete(comment.replies)) {
                return YES;
            }
        }
    }

    return NO;
}

static void flattenTree(NSArray *comments, NSMutableDictionary *dictionary) {
    for (RKComment *comment in comments) {
        if (![comment respondsToSelector:@selector(body)]) continue;
        if (isDeleted(comment.body)) {
            dictionary[comment.identifier] = comment;
        }
        flattenTree(comment.replies, dictionary);
    }
}

static void undeleteComments(NSString *ident, NSArray *comments) {
    // flatten the comment tree into a dictionary of deleted comments
    NSMutableDictionary *deletedComments = [NSMutableDictionary dictionary];
    flattenTree(comments, deletedComments);

    NSLog(@"Attempting to undelete %lu comments...", (unsigned long)deletedComments.count);

    // now get the values and sort them by ascending date
    NSArray<RKComment *> *dates = [deletedComments.allValues
        sortedArrayUsingComparator:^NSComparisonResult(RKComment *a, RKComment *b) {
            return [a.created compare:b.created];
        }];

    NSArray *pushshiftComments = getPushshiftCommentsForArray(ident, dates, CommentNarwhal, useIDs);
    NSLog(@"Got %d comments from pushshift", (int)pushshiftComments.count);
    int undeleteCount = 0;

    for (NSDictionary *psComment in pushshiftComments) {
        if (deletedComments[psComment[@"id"]] && !isDeleted(psComment[@"body"])) {
            NSLog(@"Undeleting %@", psComment[@"id"]);
            RKComment *comment = deletedComments[psComment[@"id"]];
            MSHookIvar<NSString *>(comment, "_authorFlairText") = comment.body;
            MSHookIvar<NSString *>(comment, "_body") =
                [psComment[@"body"] stringByReplacingOccurrencesOfString:@"&#x200B;"
                                                              withString:@"\u200B"];
            MSHookIvar<NSString *>(comment, "_author") = psComment[@"author"];
            // mark undeleted comments as "admin" because "special" isn't supported
            if (highlight) comment.distinguished = @"admin";
            undeleteCount++;
        }
    }

    NSLog(@"Undeleted %d comments out of %lu", undeleteCount, (unsigned long)deletedComments.count);
}

static void undeletePost(NSString *ident, RKLink *link) {
    NSLog(@"Attempting to undelete post...");
    NSDictionary *post = getPushshiftPost(ident);

    if (post) {
        MSHookIvar<NSString *>(link, "_author") = post[@"author"];
        MSHookIvar<NSString *>(link, "_title") = post[@"title"];
        MSHookIvar<NSString *>(link, "_URL") = post[@"url"];
        // narwhal doesn't support author flair text, append to the title flair instead
        MSHookIvar<NSString *>(link, "_linkFlairText") =
            link.linkFlairText ? [NSString stringWithFormat:@"%@ | %@", link.linkFlairText, link.selfText]
                               : link.selfText;
        MSHookIvar<NSString *>(link, "_selfText") =
            [post[@"selftext"] stringByReplacingOccurrencesOfString:@"&#x200B;"
                                                         withString:@"\u200B"];
        // narwhal doesn't support distinguished posts for some reason :(
        // if (highlight) MSHookIvar<NSString *>(link, "_distinguished") = @"admin";
    }
}

%group Narwhal
%hook RKClient

- (id)commentsForLinkWithIdentifier:(NSString *)ident
                               sort:(unsigned long long)arg2
                              limit:(long long)arg3
                         completion:(RKArrayCompletionBlock)completion {
    RKArrayCompletionBlock c2 = ^(NSArray *collection, NSError *error) {
        if (enabled && narwhalEnabled && shouldUndelete(collection)) {
            dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul);
            dispatch_async(queue, ^{
                undeleteComments(ident, collection);
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(collection, error);
                });
            });
        } else {
            completion(collection, error);
        }
    };

    return %orig(ident, arg2, arg3, c2);
}

- (id)context:(unsigned long long)arg1
    forCommentWithIdentifier:(id)arg2
              linkIdentifier:(NSString *)ident
                  completion:(RKArrayCompletionBlock)completion {
    RKArrayCompletionBlock c2 = ^(NSArray *collection, NSError *error) {
        if (enabled && narwhalEnabled && shouldUndelete(collection)) {
            dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul);
            dispatch_async(queue, ^{
                undeleteComments(ident, collection);
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(collection, error);
                });
            });
        } else {
            completion(collection, error);
        }
    };

    return %orig(arg1, arg2, ident, c2);
}

- (id)moreComments:(id)arg1
           forLink:(RKLink *)link
              sort:(long long)arg3
        completion:(RKArrayCompletionBlock)completion {
    RKArrayCompletionBlock c2 = ^(NSArray *collection, NSError *error) {
        if (enabled && narwhalEnabled && shouldUndelete(collection)) {
            dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul);
            dispatch_async(queue, ^{
                undeleteComments(link.identifier, collection);
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(collection, error);
                });
            });
        } else {
            completion(collection, error);
        }
    };

    return %orig(arg1, link, arg3, c2);
}

- (id)linkWithFullName:(NSString *)ident completion:(RKObjectCompletionBlock)completion {
    RKObjectCompletionBlock c2 = ^(RKLink *object, NSError *error) {
        if (enabled && narwhalEnabled && object.selfText && isDeleted(object.selfText)) {
            dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul);
            dispatch_async(queue, ^{
                undeletePost(ident, object);
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(object, error);
                });
            });
        } else {
            completion(object, error);
        }
    };

    return %orig(ident, c2);
}

- (NSURLSessionDataTask *)subredditWithName:(NSString *)subredditName
                                 completion:(RKObjectCompletionBlock)completion {
    RKObjectCompletionBlock c2 = ^(id object, NSError *error) {
        if (error && error.userInfo[@"RDKClientResponseObjectKey"][@"reason"] &&
            [error.userInfo[@"RDKClientResponseObjectKey"][@"reason"] isEqualToString:@"banned"]) {
            RKSubreddit *subreddit =
                [%c(MTLJSONAdapter) modelOfClass:[%c(RKSubreddit) class]
                                         fromJSONDictionary:@{
                                             @"kind" : @"t5",
                                             @"data" : @{
                                                 @"display_name" : subredditName,
                                             }
                                         }];
            completion(subreddit, nil);
            return;
        }
        completion(object, error);
    };

    return %orig(subredditName, c2);
}

- (id)linksInSubredditWithName:(NSString *)subreddit
                      category:(NSInteger)arg1
                    pagination:(id)arg2
                    completion:(RKListingCompletionBlock)completion {
    RKListingCompletionBlock c2 = ^(NSArray *collection, id pagination, NSError *error) {
        if (error && error.userInfo[@"RDKClientResponseObjectKey"][@"reason"] &&
            [error.userInfo[@"RDKClientResponseObjectKey"][@"reason"] isEqualToString:@"banned"] &&
            enabled && narwhalEnabled) {
            dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul);
            dispatch_async(queue, ^{
                NSArray *data = getPushshiftPostsForSubreddit(subreddit);
                if (data.count > 0) {
                    NSMutableArray *posts = [NSMutableArray array];
                    NSDictionary *banInfo = getSubredditBanInfo(subreddit, YES);

                    RKLink *bannedSticky = [%c(MTLJSONAdapter)
                              modelOfClass:[%c(RKLink) class]
                        fromJSONDictionary:@{
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
                                @"selftext_html" :
                                    @"<div class=\"md\">"
                                     "<p><a href=\"https://hgrunt.xyz\">cool site</a></p>"
                                     "</div>"
                            }
                        }];

                    [posts addObject:bannedSticky];

                    // loop through data and generate RKLinks
                    for (NSMutableDictionary *psPost in data) {
                        // small fixups
                        psPost[@"likes"] = [NSNull null];
                        psPost[@"archived"] = @YES;
                        psPost[@"selftext_html"] =
                            @"<div class=\"md\">"
                             "<p><a href=\"https://hgrunt.xyz\">cool site</a></p>"
                             "</div>";

                        // leverage existing NSDict->RKLink
                        RKLink *post = [%c(MTLJSONAdapter)
                                  modelOfClass:[%c(RKLink) class]
                            fromJSONDictionary:@{@"kind" : @"t3", @"data" : psPost}];

                        [posts addObject:post];
                    }

                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(posts, pagination, nil);
                    });
                    return;
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(collection, pagination, error);
                    });
                    return;
                }
            });
            return;
        }

        completion(collection, pagination, error);
    };

    return %orig(subreddit, arg1, arg2, c2);
}

%end
%end

static void loadPrefs() {
    NSMutableDictionary *settings = [[NSMutableDictionary alloc]
        initWithContentsOfFile:@"/var/mobile/Library/Preferences/xyz.hgrunt.autoundelete.plist"];

    enabled = getBool(settings, @"isEnabled");
    narwhalEnabled = getBool(settings, @"isNarwhalEnabled");
    highlight = getBool(settings, @"shouldHighlight");
    useIDs = getBool(settings, @"useIDs");
}

%ctor {
    loadPrefs();
    if ([NSProcessInfo.processInfo.processName isEqualToString:@"narwhal"] && enabled && narwhalEnabled) {
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)loadPrefs,
            (CFStringRef) @"xyz.hgrunt.autoundelete/preferences.changed", NULL,
            CFNotificationSuspensionBehaviorCoalesce);
        %init(Narwhal);
    }
}
