//
//  DTHTMLElement+lite.h
//  CoreTextExtensions
//
//  Created by Oliver Drobnik on 4/14/11.
//  Copyright 2011 Drobnik.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DTTextAttachment.h"

@interface DTHTMLElement : NSObject <NSCopying>
{
    DTTextAttachment *textAttachment;
    NSURL *link;
    
    NSString *tagName;
    NSString *text;
    
    NSInteger headerLevel;
    NSInteger _isInline;

	NSMutableDictionary *_additionalAttributes;
}

@property (nonatomic, retain) DTTextAttachment *textAttachment;
@property (nonatomic, copy) NSURL *link;

@property (nonatomic, copy) NSString *tagName;
@property (nonatomic, copy) NSString *text;

@property (nonatomic, assign) NSInteger headerLevel;
@property (nonatomic, readonly) BOOL isInline;


- (NSString *)string;
- (NSDictionary *)attributesDictionary;

- (void)addAdditionalAttribute:(id)attribute forKey:(id)key;


@end
