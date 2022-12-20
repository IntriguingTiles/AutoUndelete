//
//     Generated by class-dump 3.5 (64 bit).
//
//  Copyright (C) 1997-2019 Steve Nygard.
//

#import <objc/NSObject.h>

@class MTLModel, NSDictionary;
@protocol MTLJSONSerializing;

@interface MTLJSONAdapter : NSObject
{
    MTLModel<MTLJSONSerializing> *_model;
    Class _modelClass;
    NSDictionary *_JSONKeyPathsByPropertyKey;
}

+ (id)JSONArrayFromModels:(id)arg1;
+ (id)JSONDictionaryFromModel:(id)arg1;
+ (id)modelsOfClass:(Class)arg1 fromJSONArray:(id)arg2 error:(id *)arg3;
+ (id)modelOfClass:(Class)arg1 fromJSONDictionary:(NSDictionary*)arg2 error:(NSError**)arg3;
+ (id)modelOfClass:(Class)arg1 fromJSONDictionary:(id)arg2;
@property(readonly, copy, nonatomic) NSDictionary *JSONKeyPathsByPropertyKey; // @synthesize JSONKeyPathsByPropertyKey=_JSONKeyPathsByPropertyKey;
@property(readonly, nonatomic) Class modelClass; // @synthesize modelClass=_modelClass;
@property(readonly, nonatomic) MTLModel<MTLJSONSerializing> *model; // @synthesize model=_model;
- (id)JSONKeyPathForPropertyKey:(id)arg1;
- (id)JSONTransformerForKey:(id)arg1;
- (id)JSONDictionary;
- (id)initWithModel:(id)arg1;
- (id)initWithJSONDictionary:(id)arg1 modelClass:(Class)arg2 error:(id*)arg3;
- (id)init;
- (id)initWithJSONDictionary:(id)arg1 modelClass:(Class)arg2;

@end

