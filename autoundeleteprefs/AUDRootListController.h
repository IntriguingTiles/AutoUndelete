#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>

@interface AUDRootListController : PSListController
@property(strong, nonatomic) PSSpecifier *latestPostSpecifier;
@property(strong, nonatomic) PSSpecifier *latestCommentSpecifier;
- (void)checkLatest:(PSSpecifier *)arg1;
- (void)performPushshiftRequest:(BOOL)isComment insertAfterSpecifier:(PSSpecifier *)arg2;
- (void)insertLatestTimeCell:(NSDictionary *)data;
- (void)possiblyBothChecksComplete:(PSSpecifier *)arg1;
@end
