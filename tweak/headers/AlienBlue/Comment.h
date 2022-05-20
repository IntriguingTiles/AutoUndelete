//
//     Generated by class-dump 3.5 (64 bit).
//
//  Copyright (C) 1997-2019 Steve Nygard.
//

#import "VotableElement.h"

@class NSAttributedString, NSMutableArray, NSString;

@interface Comment : VotableElement
{
    NSString *_body;
    NSString *_bodyHTML;
    NSMutableArray *_links;
    unsigned long long _numberOfReplies;
    unsigned long long _commentIndex;
    NSString *_parentName;
    NSString *_parentIdent;
    NSString *_linkIdent;
    NSString *_flairText;
    NSAttributedString *_cachedStyledBody;
}

+ (id)commentFromDictionary:(id)arg1;
@property(retain, nonatomic) NSAttributedString *cachedStyledBody; // @synthesize cachedStyledBody=_cachedStyledBody;
@property(retain, nonatomic) NSString *flairText; // @synthesize flairText=_flairText;
@property(retain, nonatomic) NSString *linkIdent; // @synthesize linkIdent=_linkIdent;
@property(retain, nonatomic) NSString *parentIdent; // @synthesize parentIdent=_parentIdent;
@property(retain, nonatomic) NSString *parentName; // @synthesize parentName=_parentName;
@property unsigned long long commentIndex; // @synthesize commentIndex=_commentIndex;
@property unsigned long long numberOfReplies; // @synthesize numberOfReplies=_numberOfReplies;
@property(retain, nonatomic) NSMutableArray *links; // @synthesize links=_links;
@property(retain, nonatomic) NSString *bodyHTML; // @synthesize bodyHTML=_bodyHTML;
@property(retain, nonatomic) NSString *body; // @synthesize body=_body;
- (id)initWithDictionary:(id)arg1;
- (void)flushCachedStyles;

@end
