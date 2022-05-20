#import <Foundation/Foundation.h>
#import "AUDRootListController.h"

@implementation AUDRootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }

    return _specifiers;
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *path = [NSString
        stringWithFormat:@"/User/Library/Preferences/%@.plist", specifier.properties[@"defaults"]];
    NSMutableDictionary *settings = [NSMutableDictionary dictionary];
    [settings addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:path]];
    return (settings[specifier.properties[@"key"]]) ?: specifier.properties[@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *path = [NSString
        stringWithFormat:@"/User/Library/Preferences/%@.plist", specifier.properties[@"defaults"]];
    NSMutableDictionary *settings = [NSMutableDictionary dictionary];
    [settings addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:path]];
    settings[specifier.properties[@"key"]] = value;
    [settings writeToFile:path atomically:YES];
    CFStringRef notificationName = (__bridge CFStringRef)specifier.properties[@"PostNotification"];
    if (notificationName) {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                             notificationName, NULL, NULL, YES);
    }
}

- (void)checkLatest:(PSSpecifier *)arg1 {
    NSIndexPath *indexPath = [self indexPathForSpecifier:arg1];
    UITableViewCell *cell = [self.table cellForRowAtIndexPath:indexPath];

    cell.userInteractionEnabled = NO;

    NSInteger activityIndicatorStyle;
    if (@available(iOS 13, *)) {
        activityIndicatorStyle = UIActivityIndicatorViewStyleMedium;
    } else {
        activityIndicatorStyle = 2;  // UIActivityIndicatorViewStyleGray == 2
    }
    UIActivityIndicatorView *activityView =
        [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:activityIndicatorStyle];

    cell.accessoryView = activityView;
    [activityView startAnimating];

    // removes latest time rows if they already exist
    if (_latestPostSpecifier) {
        [self removeSpecifier:_latestPostSpecifier animated:YES];
        _latestPostSpecifier = nil;
    }
    if (_latestCommentSpecifier) {
        [self removeSpecifier:_latestCommentSpecifier animated:YES];
        _latestCommentSpecifier = nil;
    }

    // performs the requests for the most recent comment and post
    [self performPushshiftRequest:YES insertAfterSpecifier:arg1];
    [self performPushshiftRequest:NO insertAfterSpecifier:arg1];
}

- (void)performPushshiftRequest:(BOOL)isComment insertAfterSpecifier:(PSSpecifier *)arg2 {
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    int curTime = [[NSDate alloc] init].timeIntervalSince1970;

    if (isComment) {
        request.URL = [NSURL URLWithString:@"https://api.pushshift.io/reddit/search/comment/"
                                           @"?fields=created_utc&size=1&q=*"];
    } else {
        request.URL = [NSURL URLWithString:@"https://api.pushshift.io/reddit/search/submission/"
                                           @"?fields=created_utc&size=1&q=*"];
    }

    request.HTTPMethod = @"GET";

    NSURLSessionDataTask *dataTask = [NSURLSession.sharedSession
        dataTaskWithRequest:request
          completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
              NSString *resultText;

              if (data) {
                  id jsonData =
                      [[NSJSONSerialization JSONObjectWithData:data options:0
                                                         error:&error] objectForKey:@"data"];
                  if (jsonData && [jsonData count] != 0) {
                      NSDateComponentsFormatter *formatter = [[NSDateComponentsFormatter alloc] init];
                      formatter.unitsStyle = NSDateComponentsFormatterUnitsStyleFull;
                      resultText = [NSString
                          stringWithFormat:@"%@ ago",
                                           [formatter stringFromTimeInterval:curTime - [jsonData[0][@"created_utc"]
                                                                                           intValue]]];
                  } else {
                      resultText = @"no data returned";
                  }
              }

              if (error) {
                  resultText = [NSString stringWithFormat:@"HTTP Status: %li, Error: %@",
                                                          (long)((NSHTTPURLResponse *)response).statusCode,
                                                          error.localizedDescription];
              }

              NSString *labelText =
                  [NSString stringWithFormat:@"Last %@: %@", isComment ? @"Comment" : @"Post", resultText];

              // specifier to create new table row
              PSSpecifier *customSpecifier = [PSSpecifier preferenceSpecifierNamed:labelText
                                                                            target:self
                                                                               set:NULL
                                                                               get:NULL
                                                                            detail:Nil
                                                                              cell:PSStaticTextCell
                                                                              edit:Nil];
              [customSpecifier setProperty:labelText forKey:@"label"];
              [customSpecifier setProperty:@"PSStaticTextCell" forKey:@"cell"];

              if (isComment) {
                  _latestCommentSpecifier = customSpecifier;
              } else {
                  _latestPostSpecifier = customSpecifier;
              }

              NSDictionary *dataDict =
                  @{@"custom_specifier" : customSpecifier, @"after_specifier" : arg2};
              [self performSelectorOnMainThread:@selector(insertLatestTimeCell:)
                                     withObject:dataDict
                                  waitUntilDone:NO];
              [self performSelectorOnMainThread:@selector(possiblyBothChecksComplete:)
                                     withObject:arg2
                                  waitUntilDone:NO];
          }];
    [dataTask resume];
}

- (void)insertLatestTimeCell:(NSDictionary *)data {
    if (data[@"custom_specifier"] && data[@"after_specifier"]) {
        [self insertSpecifier:data[@"custom_specifier"]
               afterSpecifier:data[@"after_specifier"]
                     animated:YES];
    }
}

- (void)possiblyBothChecksComplete:(PSSpecifier *)arg1 {
    // only when both the comment and the post request have finished
    if (_latestPostSpecifier && _latestCommentSpecifier) {
        NSIndexPath *indexPath = [self indexPathForSpecifier:arg1];
        UITableViewCell *cell = [self.table cellForRowAtIndexPath:indexPath];

        if (cell) {
            UIActivityIndicatorView *activityView = (UIActivityIndicatorView *)cell.accessoryView;
            [activityView stopAnimating];
            cell.accessoryView = nil;

            cell.userInteractionEnabled = YES;
        }
    }
}

@end
