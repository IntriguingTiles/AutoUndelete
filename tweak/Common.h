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
NSArray *getPushshiftCommentsWithIDs(NSArray<NSString *> *ids);
NSArray *getPushshiftCommentsWithDate(NSString *ident, int minDate);
NSDictionary *getPushshiftPost(NSString *ident);
double getDateForComment(id comment, CommentType type);
NSString *getKeyForCommentID(CommentType type);
NSArray *getPushshiftCommentsForArray(NSString *ident, NSArray *comments, CommentType type, BOOL byID);
NSString *markdownToHTML(NSString *markdown);

#ifdef __cplusplus
}
#endif
