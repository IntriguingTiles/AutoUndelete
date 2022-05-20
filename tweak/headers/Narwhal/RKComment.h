//
//     Generated by class-dump 3.5 (64 bit).
//
//  Copyright (C) 1997-2019 Steve Nygard.
//

#import "RKVotable.h"

@class NSArray, NSAttributedString, NSDate, NSString;

@interface RKComment : RKVotable
{
    _Bool _archived;
    _Bool _saved;
    _Bool _stickied;
    _Bool _scoreHidden;
    NSString *_approvedBy;
    NSString *_author;
    NSString *_linkAuthor;
    NSString *_bannedBy;
    NSString *_body;
    NSString *_bodyHTML;
    NSDate *_edited;
    unsigned long long _gilded;
    NSString *_linkID;
    NSString *_linkTitle;
    unsigned long long _totalReports;
    NSString *_parentID;
    unsigned long long _controversiality;
    NSString *_subreddit;
    NSString *_subredditID;
    unsigned long long _distinguishedStatus;
    NSString *_distinguished;
    NSArray *_replies;
    NSString *_submissionContentText;
    NSString *_submissionContentHTML;
    NSString *_submissionLink;
    NSString *_submissionParent;
    NSString *_authorFlairClass;
    NSString *_authorFlairText;
}

+ (id)editedJSONTransformer;
+ (id)repliesJSONTransformer;
+ (id)JSONKeyPathsByPropertyKey;

@property(readonly, copy, nonatomic) NSString *authorFlairText; // @synthesize authorFlairText=_authorFlairText;
@property(readonly, copy, nonatomic) NSString *authorFlairClass; // @synthesize authorFlairClass=_authorFlairClass;
@property(readonly, copy, nonatomic) NSString *submissionParent; // @synthesize submissionParent=_submissionParent;
@property(readonly, copy, nonatomic) NSString *submissionLink; // @synthesize submissionLink=_submissionLink;
@property(readonly, copy, nonatomic) NSString *submissionContentHTML; // @synthesize submissionContentHTML=_submissionContentHTML;
@property(readonly, copy, nonatomic) NSString *submissionContentText; // @synthesize submissionContentText=_submissionContentText;
@property(readonly, nonatomic) NSArray *replies; // @synthesize replies=_replies;
@property(copy, nonatomic) NSString *distinguished; // @synthesize distinguished=_distinguished;
@property(readonly, nonatomic) unsigned long long distinguishedStatus; // @synthesize distinguishedStatus=_distinguishedStatus;
@property(readonly, copy, nonatomic) NSString *subredditID; // @synthesize subredditID=_subredditID;
@property(readonly, copy, nonatomic) NSString *subreddit; // @synthesize subreddit=_subreddit;
@property(readonly, nonatomic) unsigned long long controversiality; // @synthesize controversiality=_controversiality;
@property(readonly, nonatomic) _Bool scoreHidden; // @synthesize scoreHidden=_scoreHidden;
@property(readonly, copy, nonatomic) NSString *parentID; // @synthesize parentID=_parentID;
@property(nonatomic) unsigned long long totalReports; // @synthesize totalReports=_totalReports;
@property(readonly, copy, nonatomic) NSString *linkTitle; // @synthesize linkTitle=_linkTitle;
@property(readonly, copy, nonatomic) NSString *linkID; // @synthesize linkID=_linkID;
@property(readonly, nonatomic, getter=isStickied) _Bool stickied; // @synthesize stickied=_stickied;
@property(readonly, nonatomic, getter=isSaved) _Bool saved; // @synthesize saved=_saved;
@property(readonly, nonatomic, getter=isArchived) _Bool archived; // @synthesize archived=_archived;
@property(readonly, nonatomic) unsigned long long gilded; // @synthesize gilded=_gilded;
@property(readonly, nonatomic) NSDate *edited; // @synthesize edited=_edited;
@property(readonly, copy, nonatomic) NSString *bodyHTML; // @synthesize bodyHTML=_bodyHTML;
@property(readonly, copy, nonatomic) NSString *body; // @synthesize body=_body;
@property(readonly, copy, nonatomic) NSString *bannedBy; // @synthesize bannedBy=_bannedBy;
@property(readonly, copy, nonatomic) NSString *linkAuthor; // @synthesize linkAuthor=_linkAuthor;
@property(readonly, copy, nonatomic) NSString *author; // @synthesize author=_author;
@property(readonly, copy, nonatomic) NSString *approvedBy; // @synthesize approvedBy=_approvedBy;
- (_Bool)isDeleted;
- (id)description;
@property(nonatomic) _Bool isAdmin; // @dynamic isAdmin;
@property(nonatomic) _Bool isModerator; // @dynamic isModerator;
@property(retain, nonatomic) NSArray *bodyLinks; // @dynamic bodyLinks;
@property(retain, nonatomic) NSAttributedString *bodyAttributedString; // @dynamic bodyAttributedString;
@property(nonatomic) _Bool collapsed;
@property(nonatomic) _Bool isOriginalPoster; // @dynamic isOriginalPoster;
@property(nonatomic) _Bool lastChild; // @dynamic lastChild;
@property(nonatomic) _Bool firstChild; // @dynamic firstChild;
@property(nonatomic) unsigned long long numberOfChildren;
@property(nonatomic) unsigned long long indentation; // @dynamic indentation;
- (id)flairText;

// Remaining properties
// @property(readonly, nonatomic) long long score; // @dynamic score;

@end

