#import <Common.h>
#import <Foundation/Foundation.h>
#import <headers/Apollo/MTLJSONAdapter.h>
#import <headers/Apollo/RDKComment.h>
#import <headers/Apollo/RDKLink.h>

static BOOL enabled;
static BOOL apolloEnabled;
static BOOL highlight;
static BOOL useIDs;

typedef void (^RDKDictionaryCompletionBlock)(NSDictionary *collection, NSError *error);
typedef void (^RDKArrayCompletionBlock)(NSArray *collection, NSError *error);
typedef void (^RDKListingCompletionBlock)(NSArray *collection, id pagination, NSError *error);

static BOOL shouldUndelete(NSArray *comments) {
    for (RDKComment *comment in comments) {
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
    for (RDKComment *comment in comments) {
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
    NSArray<RDKComment *> *dates = [deletedComments.allValues
        sortedArrayUsingComparator:^NSComparisonResult(RDKComment *a, RDKComment *b) {
            return [a.createdUTC compare:b.createdUTC];
        }];

    NSArray *pushshiftComments = getPushshiftCommentsForArray(ident, dates, CommentApollo, useIDs);
    NSLog(@"Got %d comments from pushshift", (int)pushshiftComments.count);
    int undeleteCount = 0;

    for (NSDictionary *psComment in pushshiftComments) {
        if (deletedComments[psComment[@"id"]] && !isDeleted(psComment[@"body"])) {
            NSLog(@"Undeleting %@", psComment[@"id"]);
            RDKComment *comment = deletedComments[psComment[@"id"]];
            comment.authorFlairPlaintext = comment.body;
            comment.author = psComment[@"author"];
            comment.body = psComment[@"body"];
            // mark undeleted comments as "special"
            if (highlight) comment.distinguished = 3;
            // apollo doesn't just parse the raw markdown but also seems to inspect the body html
            // without doing this, it'll refuse to properly parse the markdown
            comment.bodyHTML = @"<div class=\"md\">"
                                "<p><a href=\"https://hgrunt.xyz\">cool site</a></p>"
                                "</div>";
            undeleteCount++;
        }
    }

    NSLog(@"Undeleted %d comments out of %lu", undeleteCount, (unsigned long)deletedComments.count);
}

static void undeletePost(NSString *ident, RDKLink *link) {
    NSLog(@"Attempting to undelete post...");
    NSDictionary *post = getPushshiftPost(ident);

    // it's possible for the pushshift response to still be [deleted] or [removed]
    // but sometimes it still has more info than what reddit api returned so it's still worth trying
    if (post) {
        link.author = post[@"author"];
        link.title = post[@"title"];
        link.authorFlairPlaintext = link.selfText;
        if (highlight) link.distinguished = 3;
        link.selfText = post[@"selftext"];
        link.selfTextHTML = @"<div class=\"md\">"
                             "<p><a href=\"https://hgrunt.xyz\">cool site</a></p>"
                             "</div>";
        link.URL = [NSURL URLWithString:post[@"url"]];
        link.selfPost = [post[@"is_self"] boolValue];
    }
}

%group Apollo
%hook RDKClient

- (id)linkAndCommentsForLinkWithIdentifier:(NSString *)ident
                               commentSort:(long long)arg2
                                pagination:(id)arg3
                                completion:(RDKDictionaryCompletionBlock)completion {
    RDKDictionaryCompletionBlock c2 = ^(NSDictionary *collection, NSError *error) {
        RDKLink *link = collection[@"link"];

        if (enabled && apolloEnabled) {
            dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul);
            dispatch_async(queue, ^{
                if (shouldUndelete(collection[@"comments"])) {
                    undeleteComments(ident, collection[@"comments"]);
                }

                if (link.isSelfPostWithSelfText && isDeleted(link.selfText)) {
                    undeletePost(ident, link);
                }

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

- (id)moreComments:(id)arg1
           forLink:(RDKLink *)link
              sort:(long long)arg3
        completion:(RDKArrayCompletionBlock)completion {
    RDKArrayCompletionBlock c2 = ^(NSArray *collection, NSError *error) {
        if (enabled && apolloEnabled && shouldUndelete(collection)) {
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

- (id)linkAndContext:(long long)arg1
    forCommentWithIdentifier:(id)arg2
              linkIdentifier:(id)linkIdentifier
                 commentSort:(long long)arg4
                  pagination:(id)arg5
                  completion:(RDKDictionaryCompletionBlock)completion {
    RDKDictionaryCompletionBlock c2 = ^(NSDictionary *collection, NSError *error) {
        RDKLink *link = collection[@"link"];

        if (enabled && apolloEnabled) {
            dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul);
            dispatch_async(queue, ^{
                if (shouldUndelete(collection[@"comments"])) {
                    undeleteComments(linkIdentifier, collection[@"comments"]);
                }

                if (link.isSelfPostWithSelfText && isDeleted(link.selfText)) {
                    undeletePost(linkIdentifier, link);
                }

                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(collection, error);
                });
            });
        } else {
            completion(collection, error);
        }
    };

    return %orig(arg1, arg2, linkIdentifier, arg4, arg5, c2);
}

- (id)context:(unsigned long long)arg1
    forCommentWithIdentifier:(id)arg2
              linkIdentifier:(id)ident
                  completion:(RDKArrayCompletionBlock)completion {
    RDKArrayCompletionBlock c2 = ^(NSArray *collection, NSError *error) {
        if (enabled && apolloEnabled && shouldUndelete(collection)) {
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

- (id)linksInSubredditWithName:(NSString *)subreddit
                      category:(NSInteger)arg1
                    pagination:(id)arg2
                    completion:(RDKListingCompletionBlock)completion {
    RDKListingCompletionBlock c2 = ^(NSArray *collection, id pagination, NSError *error) {
        if (error.code == 450 && enabled && apolloEnabled) {
            // code 450 == banned subreddit
            dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul);
            dispatch_async(queue, ^{
                NSArray *data = getPushshiftPostsForSubreddit(subreddit);
                if (data.count > 0) {
                    NSMutableArray *posts = [NSMutableArray array];
                    NSDictionary *banInfo = getSubredditBanInfo(subreddit, YES);

                    RDKLink *bannedSticky = [%c(MTLJSONAdapter)
                              modelOfClass:[%c(RDKLink) class]
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

                    // loop through data and generate RDKLinks
                    for (NSMutableDictionary *psPost in data) {
                        // small fixups
                        psPost[@"likes"] = [NSNull null];
                        psPost[@"archived"] = @YES;
                        psPost[@"selftext_html"] =
                            @"<div class=\"md\">"
                             "<p><a href=\"https://hgrunt.xyz\">cool site</a></p>"
                             "</div>";

                        // leverage existing NSDict->RDKLink
                        RDKLink *post = [%c(MTLJSONAdapter)
                                  modelOfClass:[%c(RDKLink) class]
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
    apolloEnabled = getBool(settings, @"isApolloEnabled");
    highlight = getBool(settings, @"shouldHighlight");
    useIDs = getBool(settings, @"useIDs");
}

%ctor {
    loadPrefs();
    if ([NSProcessInfo.processInfo.processName isEqualToString:@"Apollo"] && enabled && apolloEnabled) {
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)loadPrefs,
            (CFStringRef) @"xyz.hgrunt.autoundelete/preferences.changed", NULL,
            CFNotificationSuspensionBehaviorCoalesce);
        %init(Apollo);
    }
}
