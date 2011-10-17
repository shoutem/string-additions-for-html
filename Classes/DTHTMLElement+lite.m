//
//  DTHTMLElement.m
//  CoreTextExtensions
//
//  Created by Oliver Drobnik on 4/14/11.
//  Copyright 2011 Drobnik.com. All rights reserved.
//

#import "DTHTMLElement+lite.h"
#import "NSString+HTML.h"
#import "UIColor+HTML.h"
#import "NSCharacterSet+HTML.h"


@implementation DTHTMLElement

- (id)init
{
    self = [super init];
    if (self)
    {
        _isInline = -1;
    }
    
    return self;
    
}



- (void)dealloc
{
    [textAttachment release];
	
    [tagName release];
    [text release];
    [link release];

	[_additionalAttributes release];
    
    [super dealloc];
}


- (NSDictionary *)attributesDictionary
{
    NSMutableDictionary *tmpDict = [NSMutableDictionary dictionary];
	
	// copy additional attributes
	if (_additionalAttributes)
	{
		[tmpDict setDictionary:_additionalAttributes];
	}
    
    // add text attachment
    if (textAttachment)
    {
        // add attachment
        [tmpDict setObject:textAttachment forKey:@"DTTextAttachment"];
    }
    else
    {
        // otherwise we have a font
    }
    
    // add hyperlink
    if (link)
    {
        [tmpDict setObject:link forKey:@"DTLink"];
        
        // add a GUID to group multiple glyph runs belonging to same link
        [tmpDict setObject:[NSString guid] forKey:@"DTGUID"];
    }
    
    return tmpDict;
}


- (NSString *)string
{
    if (textAttachment)
    {
        // ignore text, use unicode object placeholder
        return [[[NSString alloc] initWithString:UNICODE_OBJECT_PLACEHOLDER] autorelease];
    }
    else
    {
        return [[[NSString alloc] initWithString:text] autorelease];
    }
}

- (void)addAdditionalAttribute:(id)attribute forKey:(id)key
{
	if (!_additionalAttributes)
	{
		_additionalAttributes = [[NSMutableDictionary alloc] init];
	}
	
	[_additionalAttributes setObject:attribute forKey:key];
}

#pragma mark Copying

- (id)copyWithZone:(NSZone *)zone
{
    DTHTMLElement *newObject = [[DTHTMLElement allocWithZone:zone] init];
    
    newObject.link = self.link; // copy
    
    return newObject;
}

#pragma mark Properties

- (BOOL)isInline
{
    if (_isInline<0)
    {
        _isInline = [tagName isInlineTag];
    }
    
    return _isInline;
}

@synthesize tagName;
@synthesize text;
@synthesize link;
@synthesize textAttachment;
@synthesize headerLevel;
@synthesize isInline;



@end


