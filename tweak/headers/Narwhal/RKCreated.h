//
//     Generated by class-dump 3.5 (64 bit).
//
//  Copyright (C) 1997-2019 Steve Nygard.
//

#import "RKThing.h"

@class NSDate;

@interface RKCreated : RKThing
{
    NSDate *_created;
}

+ (id)createdJSONTransformer;
+ (id)JSONKeyPathsByPropertyKey;

@property(retain, nonatomic) NSDate *created; // @synthesize created=_created;
- (id)prettyLongDate;
- (id)prettyDate;

@end
