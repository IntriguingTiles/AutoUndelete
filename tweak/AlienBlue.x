#import <Common.h>
#import <Foundation/Foundation.h>
#import <headers/AlienBlue/Comment.h>
#import <headers/AlienBlue/CommentNode.h>
#import <headers/AlienBlue/CommentPostHeaderNode.h>
#import <headers/AlienBlue/Post.h>
#import <snudown/snudown.h>

static BOOL enabled;
static BOOL alienBlueEnabled;
static BOOL highlight;
static BOOL useIDs;

typedef void (^REDPostCompletion)(NSArray *comments, CommentPostHeaderNode *post);

static BOOL shouldUndelete(NSArray *comments) {
    for (CommentNode *node in comments) {
        Comment *comment = node.comment;
        if (comment && isDeleted(comment.body)) {
            return YES;
        }
    }

    return NO;
}

static void undeleteComments(NSString *ident, NSArray *comments) {
    // turn the array into a dictionary of deleted comments
    NSMutableDictionary *deletedComments = [NSMutableDictionary dictionary];

    for (CommentNode *node in comments) {
        Comment *comment = node.comment;
        if (comment && isDeleted(comment.body)) {
            deletedComments[comment.ident] = comment;
        }
    }

    NSLog(@"Attempting to undelete %lu comments...", (unsigned long)deletedComments.count);

    // now get the values and sort them by ascending date
    NSArray<Comment *> *dates = [deletedComments.allValues
        sortedArrayUsingComparator:^NSComparisonResult(Comment *a, Comment *b) {
            return [a.createdDate compare:b.createdDate];
        }];

    NSArray *pushshiftComments = getPushshiftCommentsForArray(ident, dates, CommentAlienBlue, useIDs);
    NSLog(@"Got %d comments from pushshift", (int)pushshiftComments.count);
    int undeleteCount = 0;

    for (NSDictionary *psComment in pushshiftComments) {
        if (deletedComments[psComment[@"id"]] && !isDeleted(psComment[@"body"])) {
            NSLog(@"Undeleting %@", psComment[@"id"]);
            Comment *comment = deletedComments[psComment[@"id"]];
            comment.flairText = comment.body;
            comment.author = psComment[@"author"];
            comment.body = psComment[@"body"];
            comment.bodyHTML = markdownToHTML(psComment[@"body"]);
            // mark undeleted comments as "admin" because "special" didn't exist yet
            if (highlight) comment.distinguishedStr = @"admin";
            [comment flushCachedStyles];
            undeleteCount++;
        }
    }

    NSLog(@"Undeleted %d comments out of %lu", undeleteCount, (unsigned long)deletedComments.count);
}

static void undeletePost(NSString *ident, Post *link, Post *link2, Comment *comment) {
    NSLog(@"Attempting to undelete post...");
    NSDictionary *post = getPushshiftPost(ident);

    if (post) {
        // this might not be necessary, but it doesn't seem to hurt?
        link.author = post[@"author"];
        link.linkFlairText = link.selftext;
        if (highlight) link.distinguishedStr = @"admin";
        link.selftext = post[@"selftext"];
        link.selftextHtml = markdownToHTML(post[@"selftext"]);
        [link flushCachedStyles];

        // ditto
        link2.author = post[@"author"];
        link2.linkFlairText = link2.selftext;
        if (highlight) link2.distinguishedStr = @"admin";
        link2.selftext = post[@"selftext"];
        link2.selftextHtml = link.selftextHtml;
        [link2 flushCachedStyles];

        comment.flairText = comment.body;
        comment.author = post[@"author"];
        comment.body = post[@"selftext"];
        comment.bodyHTML = link.selftextHtml;
        if (highlight) comment.distinguishedStr = @"admin";
        [comment flushCachedStyles];
    }
}

%group AlienBlue
%hook CommentsViewController

- (void)fetchCommentsOnComplete:(REDPostCompletion)completion {
    REDPostCompletion c2 = ^(NSArray *comments, CommentPostHeaderNode *header) {
        if (enabled && alienBlueEnabled) {
            dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul);
            dispatch_async(queue, ^{
                if (shouldUndelete(comments)) {
                    undeleteComments([((id)self) post].ident, comments);
                }

                if (header.post.selfPost && isDeleted(header.post.selftext)) {
                    undeletePost([(id)self post].ident, header.post, [(id)self post], header.comment);
                }

                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(comments, header);
                });
            });
        } else {
            completion(comments, header);
        }
    };

    return %orig(c2);
}

%end
%end

static void loadPrefs() {
    NSMutableDictionary *settings = [[NSMutableDictionary alloc]
        initWithContentsOfFile:@"/var/mobile/Library/Preferences/xyz.hgrunt.autoundelete.plist"];

    enabled = getBool(settings, @"isEnabled");
    alienBlueEnabled = getBool(settings, @"isAlienBlueEnabled");
    highlight = getBool(settings, @"shouldHighlight");
    useIDs = getBool(settings, @"useIDs");
}

%ctor {
    loadPrefs();
    if ([NSProcessInfo.processInfo.processName isEqualToString:@"AlienBlue"] && enabled && alienBlueEnabled) {
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)loadPrefs,
            (CFStringRef) @"xyz.hgrunt.autoundelete/preferences.changed", NULL,
            CFNotificationSuspensionBehaviorCoalesce);
        initsnudown();
        %init(AlienBlue);
    }
}
