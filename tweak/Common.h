#ifdef __cplusplus
extern "C" {
#endif

#define PS_BASE @"https://api.pushshift.io/reddit"

typedef NS_ENUM(NSInteger, CommentType) {
    CommentApollo,
    CommentAlienBlue,
    CommentNarwhal,
    CommentRaw
};

BOOL getBool(NSMutableDictionary *settings, NSString *key);
BOOL isDeleted(NSString *body);
id makeJSONRequest(NSString *url);
id makeJSONRequestWithOptions(NSString *url, NSJSONReadingOptions options);
NSArray *getPushshiftCommentsWithIDs(NSArray<NSString *> *ids);
NSArray *getPushshiftCommentsWithDate(NSString *ident, int minDate);
NSDictionary *getPushshiftPost(NSString *ident);
NSMutableArray *getPushshiftPostsForSubreddit(NSString *subreddit);
double getDateForComment(id comment, CommentType type);
NSString *getKeyForCommentID(CommentType type);
NSArray *getPushshiftCommentsForArray(NSString *ident, NSArray *comments, CommentType type, BOOL byID);
NSString *markdownToHTML(NSString *markdown);
NSDictionary *getSubredditBanInfo(NSString *subreddit, BOOL asMarkdown);

#ifdef __cplusplus
}
#endif
