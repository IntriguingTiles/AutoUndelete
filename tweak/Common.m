#import "Common.h"
#import "headers/AlienBlue/Comment.h"
#import "headers/Apollo/RDKComment.h"
#import "headers/Narwhal/RKComment.h"
#import "snudown/snudown.h"

NSCache *cache = nil;

BOOL getBool(NSMutableDictionary *settings, NSString *key) {
    return [settings objectForKey:key] ? [[settings objectForKey:key] boolValue] : YES;
}

BOOL isDeleted(NSString *body) {
    return ([body isEqualToString:@"[deleted]"] || [body isEqualToString:@"[removed]"]);
}

id makeJSONRequest(NSString *url) {
    if (!cache) cache = [[NSCache alloc] init];
    if ([cache objectForKey:url]) {
        NSLog(@"Using cached result for %@", url);
        return [cache objectForKey:url];
    }

    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    request.URL = [NSURL URLWithString:url];
    request.HTTPMethod = @"GET";
    NSLog(@"Making a request to %@", request.URL);
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    __block id result = nil;

    NSURLSessionDataTask *dataTask = [NSURLSession.sharedSession
        dataTaskWithRequest:request
          completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
              if (data) {
                  id jsonData = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                  if (jsonData) {
                      result = jsonData;
                      [cache setObject:jsonData forKey:url];
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

NSArray *getPushshiftCommentsWithIDs(NSArray<NSString *> *ids) {
    NSString *idents = @"";

    for (NSString *ident in ids) {
        idents = [idents stringByAppendingString:[NSString stringWithFormat:@"%@,", ident]];
    }

    id response = makeJSONRequest([NSString
        stringWithFormat:PS_BASE
                         @"/comment/search/?ids=%@&size=100&fields=id,author,body&html_decode=true",
                         idents]);

    if (response && response[@"data"]) {
        return response[@"data"];
    } else {
        return [NSArray array];
    }
}

NSArray *getPushshiftCommentsWithDate(NSString *ident, int minDate) {
    id response = makeJSONRequest(
        [NSString stringWithFormat:PS_BASE @"/comment/search/"
                                           @"?link_id=%@&size=100&sort=asc&fields=id,author,body,"
                                           @"created_utc&after=%d&html_decode=true&q=*",
                                   ident, minDate]);

    if (response && response[@"data"]) {
        return response[@"data"];
    } else {
        return [NSArray array];
    }
}

NSDictionary *getPushshiftPost(NSString *ident) {
    id response = makeJSONRequest([NSString
        stringWithFormat:PS_BASE @"/submission/search/?ids=%@&html_decode=true&q=*", ident]);

    if (response && response[@"data"] && [response[@"data"] count] != 0) {
        return response[@"data"][0];
    } else {
        return nil;
    }
}

double getDateForComment(id comment, CommentType type) {
    switch (type) {
        case CommentApollo:
            return ((RDKComment *)comment).createdUTC.timeIntervalSince1970;
            break;
        case CommentAlienBlue:
            return ((Comment *)comment).createdDate.timeIntervalSince1970;
            break;
        case CommentNarwhal:
            return ((RKComment *)comment).created.timeIntervalSince1970;
            break;
        case CommentRaw:
            return [comment[@"created_utc"] doubleValue];
            break;
    }
}

NSString *getKeyForCommentID(CommentType type) {
    switch (type) {
        case CommentApollo:
        case CommentNarwhal:
            return @"identifier";
            break;
        case CommentAlienBlue:
            return @"ident";
            break;
        case CommentRaw:
            return @"id";
            break;
    }
}

NSArray *getPushshiftCommentsForArray(NSString *ident, NSArray *comments, CommentType type, BOOL byID) {
    if (byID) {
        NSArray *ids = [comments valueForKey:getKeyForCommentID(type)];
        return getPushshiftCommentsWithIDs(ids);
    } else {
        int minDate = floor(getDateForComment(comments.firstObject, type)) - 1;
        int maxDate = ceil(getDateForComment(comments.lastObject, type)) + 1;
        NSArray *pushshiftComments = [NSArray array];

        while (TRUE) {
            NSArray *results = getPushshiftCommentsWithDate(ident, minDate);
            pushshiftComments = [pushshiftComments arrayByAddingObjectsFromArray:results];

            if (results.count == 100 && [results.lastObject[@"created_utc"] intValue] < maxDate) {
                int newestPostDate = [results.lastObject[@"created_utc"] intValue];
                // this handles an edge case where the newest date has surpassed all the deleted comment
                // dates but not the maxDate which is +1 from what the newest comment's date is
                minDate = [results.lastObject[@"created_utc"] intValue];

                // determine what the next best minDate should be
                for (int i = 0; i < comments.count; i++) {
                    if (newestPostDate < getDateForComment(comments[i], type)) {
                        // this will be the first time the newest post date is older than one of the
                        // deleted comment dates
                        minDate = floor(getDateForComment(comments[i], type)) - 1;
                        break;
                    }
                }
            } else {
                break;
            }
        }

        return pushshiftComments;
    }
}

NSString *markdownToHTML(NSString *markdown) {
    const char *html;
    html = snudown_md(markdown.UTF8String, [markdown lengthOfBytesUsingEncoding:NSUTF8StringEncoding],
                      0, nil, nil, RENDERER_USERTEXT, 0);
    return [NSString stringWithFormat:@"<div class=\"md\">%@</div>", [NSString stringWithUTF8String:html]];
}
