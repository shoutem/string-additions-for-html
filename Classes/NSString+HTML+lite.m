//
//  NSString+HTML.m
//  CoreTextExtensions
//
//  Created by Oliver Drobnik on 1/9/11.
//  Copyright 2011 Drobnik.com. All rights reserved.
//

#import <CoreText/CoreText.h>
#import <UIKit/UIKit.h>

#import "NSString+HTML+lite.h"

#import "NSString+HTML.h"
#import "UIColor+HTML.h"
#import "NSScanner+HTML.h"
#import "NSCharacterSet+HTML.h"
#import "DTTextAttachment.h"

#import "DTHTMLElement+lite.h"

#import "CGUtils.h"

// standard options
NSString *NSBaseURLDocumentOption = @"NSBaseURLDocumentOption";
NSString *NSTextEncodingNameDocumentOption = @"NSTextEncodingNameDocumentOption";
NSString *NSTextSizeMultiplierDocumentOption = @"NSTextSizeMultiplierDocumentOption";

// custom options
NSString *DTMaxImageSize = @"DTMaxImageSize";
NSString *DTDefaultTextColor = @"DTDefaultTextColor";
NSString *DTDefaultLinkColor = @"DTDefaultLinkColor";
NSString *DTMaxTextSize = @"DTMaxTextSize";

@implementation NSString (HTML_lite)

+ (NSString*)stringWithHTMLString:(NSString *)htmlString options:(NSDictionary *)options
{
    
    // custom option to limit image size
    NSValue *maxImageSizeValue = [options objectForKey:DTMaxImageSize];
    
    // custom option to scale text
    CGFloat textScale = [[options objectForKey:NSTextSizeMultiplierDocumentOption] floatValue];
    if (!textScale)
    {
        textScale = 1.0f;
    }
	
	// use baseURL from options if present
	NSURL *baseURL = [options objectForKey:NSBaseURLDocumentOption];

    NSNumber *nMaxTextSize = [options objectForKey:DTMaxTextSize];
    NSUInteger maxTextSize = (nMaxTextSize == nil) ? UINT_MAX : [nMaxTextSize unsignedIntValue];
	
    // for performance we will return this mutable string
	NSMutableString *tmpString = [[NSMutableString alloc] init];
	
	NSMutableArray *tagStack = [NSMutableArray array];
    // NSMutableDictionary *fontCache = [NSMutableDictionary dictionaryWithCapacity:10];

#if ALLOW_IPHONE_SPECIAL_CASES
	CGFloat nextParagraphAdditionalSpaceBefore = 0.0;
#endif
	BOOL seenPreviousParagraph = NO;
	NSInteger listCounter = 0;  // Unordered, set to 1 to get ordered list
	BOOL needsListItemStart = NO;
	BOOL needsNewLineBefore = NO;
	
	
	// we cannot skip any characters, NLs turn into spaces and multi-spaces get compressed to singles
	NSScanner *scanner = [NSScanner scannerWithString:htmlString];
	scanner.charactersToBeSkipped = nil;

    id defaultLinkColor = [options objectForKey:DTDefaultLinkColor];
    
    if (defaultLinkColor)
    {
        if ([defaultLinkColor isKindOfClass:[NSString class]])
        {
            // convert from string to color
            defaultLinkColor = [UIColor colorWithHTMLName:defaultLinkColor];
        }
    }
    else
    {
        defaultLinkColor = [UIColor colorWithHTMLName:@"#0000EE"];
    }
    
    DTHTMLElement *defaultTag = [[[DTHTMLElement alloc] init] autorelease];
    
	[tagStack addObject:defaultTag];
	
	DTHTMLElement *currentTag = [tagStack lastObject];
	
	// skip initial whitespace
	[scanner scanCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:NULL];
 	
    // skip doctype tag
    [scanner scanDOCTYPE:NULL];
    
    // skip initial whitespace
	[scanner scanCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:NULL];
    
	while (![scanner isAtEnd]) 
	{
		NSString *tagName = nil;
		NSDictionary *tagAttributesDict = nil;
		BOOL tagOpen = YES;
		BOOL immediatelyClosed = NO;
        
		if ([scanner scanHTMLTag:&tagName attributes:&tagAttributesDict isOpen:&tagOpen isClosed:&immediatelyClosed] && tagName)
		{
			if (tagOpen)
			{
                // make new tag as copy of previous tag
                currentTag = [[currentTag copy] autorelease];
                currentTag.tagName = tagName;
                
                if (![currentTag isInline])
                {
                    // next text needs a NL
                    needsNewLineBefore = YES;
                }
			}
            
			// ---------- Processing
			
			if ([tagName isEqualToString:@"img"] && tagOpen)
			{
				immediatelyClosed = YES;
				
				NSString *src = [tagAttributesDict objectForKey:@"src"];
				CGFloat width = [[tagAttributesDict objectForKey:@"width"] intValue];
				CGFloat height = [[tagAttributesDict objectForKey:@"height"] intValue];
				
				// assume it's a relative file URL
                UIImage *image;
                
                if (baseURL)
                {
                    // relative file URL
                    
                    NSURL *imageURL = [NSURL URLWithString:src relativeToURL:baseURL];
                    image = [UIImage imageWithContentsOfFile:[imageURL path]];
                }
                else
                {
                    // file in app bundle
                    NSString *path = [[NSBundle mainBundle] pathForResource:src ofType:nil];
                    image = [UIImage imageWithContentsOfFile:path];
                }
				
				if (image)
				{
					if (!width)
					{
						width = image.size.width;
					}
					
					if (!height)
					{
						height = image.size.height;
					}
				}
                
                // option DTMaxImageSize
                if (maxImageSizeValue)
                {
                    CGSize maxImageSize = [maxImageSizeValue CGSizeValue];
                    
                    if (maxImageSize.width < width || maxImageSize.height < height)
                    {
                        CGSize adjustedSize = sizeThatFitsKeepingAspectRatio(image.size,maxImageSize);
                        
                        width = adjustedSize.width;
                        height = adjustedSize.height;
                    }
                }
				
				DTTextAttachment *attachment = [[[DTTextAttachment alloc] init] autorelease];
				attachment.contents = image;
				attachment.originalSize = image.size;
				attachment.displaySize = CGSizeMake(width, height);
                
                currentTag.textAttachment = attachment;
                
				if (needsNewLineBefore)
				{
					if ([tmpString length] && ![tmpString hasSuffix:@"\n"])
					{
                        [tmpString appendString:@"\n"];
					}
					
					needsNewLineBefore = NO;
				}
                
                [tmpString appendString:[currentTag string]];

#if ALLOW_IPHONE_SPECIAL_CASES
				// workaround, make float images blocks because we have no float
				if (currentTag.floatStyle)
				{
					needsNewLineBefore = YES;
				}
#endif
			}
			else if ([tagName isEqualToString:@"video"] && tagOpen)
			{
				CGFloat width = [[tagAttributesDict objectForKey:@"width"] intValue];
				CGFloat height = [[tagAttributesDict objectForKey:@"height"] intValue];
				
				if (width==0 || height==0)
				{
					width = 300;
					height = 225;
				}
				
				DTTextAttachment *attachment = [[[DTTextAttachment alloc] init] autorelease];
				attachment.contents = [NSURL URLWithString:[tagAttributesDict objectForKey:@"src"]];
                attachment.contentType = DTTextAttachmentTypeVideoURL;
				attachment.originalSize = CGSizeMake(width, height);
                
                currentTag.textAttachment = attachment;
                
                [tmpString appendString:[currentTag string]];
			}
			else if ([tagName isEqualToString:@"a"])
			{
				if (tagOpen)
				{

					// remove line breaks and whitespace in links
					NSString *cleanString = [[tagAttributesDict objectForKey:@"href"] stringByReplacingOccurrencesOfString:@"\n" withString:@""];
					cleanString = [cleanString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
					
					NSURL *link = [NSURL URLWithString:cleanString];
					
					// deal with relative URL
					if (![link scheme])
					{
						link = [NSURL URLWithString:cleanString relativeToURL:baseURL];
					}
					
                    currentTag.link = link;
				}
			}
			else if ([tagName isEqualToString:@"li"]) 
			{
				if (tagOpen)
				{
					needsListItemStart = YES;
				}
				else 
				{
					needsListItemStart = NO;
					
					if (listCounter)
					{
						listCounter++;
					}
				}
				
			}

			else if ([tagName isEqualToString:@"ol"]) 
			{
				if (tagOpen)
				{
					listCounter = 1;
				} 
				else 
				{
#if ALLOW_IPHONE_SPECIAL_CASES						
					nextParagraphAdditionalSpaceBefore = defaultFontDescriptor.pointSize;
#endif
				}
			}
			else if ([tagName isEqualToString:@"ul"]) 
			{
				if (tagOpen)
				{
					listCounter = 0;
				}
				else 
				{
#if ALLOW_IPHONE_SPECIAL_CASES						
					nextParagraphAdditionalSpaceBefore = defaultFontDescriptor.pointSize;
#endif
				}
			}

			else if ([tagName isEqualToString:@"hr"])
			{
				if (tagOpen)
				{
					immediatelyClosed = YES;
					
					// open block needs closing
					if (needsNewLineBefore)
					{
						if ([tmpString length] && ![tmpString hasSuffix:@"\n"])
						{
							[tmpString appendString:@"\n"];
						}
						
						needsNewLineBefore = NO;
					}
					
					currentTag.text = @"\n";
					
					NSMutableDictionary *styleDict = [NSMutableDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:@"Dummy"];

					[currentTag addAdditionalAttribute:styleDict forKey:@"DTHorizontalRuleStyle"];
					
					[tmpString appendString:[currentTag string]];
				}
			}
			else if ([tagName hasPrefix:@"h"])
			{
				if (tagOpen)
				{
					// First paragraph after a header needs a newline to not stick to header
					seenPreviousParagraph = NO;
				}
			}
			else if ([tagName isEqualToString:@"p"])
			{
				if (tagOpen)
				{					
					seenPreviousParagraph = YES;
				}
				
			}
            // Silvije: Need this to detect tags like '<!--'
            else if ([tagName hasPrefix:@"!"])
            {
				if (tagOpen)
				{					
					seenPreviousParagraph = YES;
				}
				
            }
			else if ([tagName isEqualToString:@"br"])
			{
				immediatelyClosed = YES; 
                
				currentTag.text = UNICODE_LINE_FEED;
				[tmpString appendString:[currentTag string]];
			}
			
			// --------------------- push tag on stack if it's opening
			if (tagOpen&&!immediatelyClosed)
			{
				[tagStack addObject:currentTag];
			}
			else if (!tagOpen)
			{
				// block items have to have a NL at the end.
				if (![currentTag isInline] && ![tmpString hasSuffix:@"\n"] && ![tmpString hasSuffix:UNICODE_OBJECT_PLACEHOLDER])
				{
                    [tmpString appendString:@"\n"];  // extends attributed area at end
				}
				
				needsNewLineBefore = NO;
				
				
				if ([tagStack count])
				{
					// check if this tag is indeed closing the currently open one
					DTHTMLElement *topStackTag = [tagStack lastObject];
					
					if ([tagName isEqualToString:topStackTag.tagName])
					{
						[tagStack removeLastObject];
						currentTag = [tagStack lastObject];
					}
					else 
					{
						DLog(@"Ignoring non-open tag %@", topStackTag.tagName);
					}
					
				}
				else 
				{
					currentTag = nil;
				}
			}
			else if (immediatelyClosed)
			{
				// If it's immediately closed it's not relevant for following body
				currentTag = [tagStack lastObject];
			}
		}
		else 
		{
			//----------------------------------------- TAG CONTENTS -----------------------------------------
			NSString *tagContents = nil;
            
            // if we find a < at this stage then we can assume it was a malformed tag, need to skip it to prevent endless loop
            
            BOOL skippedAngleBracket = NO;
            if ([scanner scanString:@"<" intoString:NULL])
            {
                skippedAngleBracket = YES;
            }
			
			if ((skippedAngleBracket||[scanner scanUpToString:@"<" intoString:&tagContents]))
			{
                if (skippedAngleBracket)
                {
                    if (tagContents)
                    {
                        tagContents = [@"<" stringByAppendingString:tagContents];
                    }
                    else
                    {
                        tagContents = @"<";
                    }
                }
                
                // Silvije: Fix for <style> tag, it needs to be ignored.
                if ([currentTag.tagName isEqualToString:@"style"])
                {
                    continue;
                }
				
				if ([[tagContents stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]] length])
				{
					tagContents = [tagContents stringByNormalizingWhitespace];
					tagContents = [tagContents stringByReplacingHTMLEntities];
                    
                    tagName = currentTag.tagName;
                    
#if ALLOW_IPHONE_SPECIAL_CASES				
					if (tagOpen && ![currentTag isInline] && ![tagName isEqualToString:@"li"])
					{
						if (nextParagraphAdditionalSpaceBefore>0)
						{
							// FIXME: add extra space properly
							// this also works, but breaks UnitTest for lists
							tagContents = [UNICODE_LINE_FEED stringByAppendingString:tagContents];
							
							// this causes problems on the paragraph after a List
							//paragraphSpacingBefore += nextParagraphAdditionalSpaceBefore;
							nextParagraphAdditionalSpaceBefore = 0;
						}
					}
#endif
					
					if (needsListItemStart)
					{
						if (listCounter)
						{
							NSString *prefix = [NSString stringWithFormat:@"\x09%d.\x09", listCounter];
							
							tagContents = [prefix stringByAppendingString:tagContents];
						}
						else
						{
							// Ul li prefixes bullet
							tagContents = [@"\x09\u2022\x09" stringByAppendingString:tagContents];
						}
						
						needsListItemStart = NO;
					}
					
					if (needsNewLineBefore)
					{
						if ([tagContents hasPrefix:@" "])
						{
							tagContents = [tagContents substringFromIndex:1];
						}
						
						if ([tmpString length])
						{
							if (![tmpString hasSuffix:@"\n"])
							{
								tagContents = [@"\n" stringByAppendingString:tagContents];
							}
						}
						needsNewLineBefore = NO;
					}
					else // might be a continuation of a paragraph, then we might need space before it
					{
						// prevent double spacing
						if ([tmpString hasSuffixCharacterFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] && [tagContents hasPrefix:@" "])
						{
							tagContents = [tagContents substringFromIndex:1];
						}
					}
                    
                    // we don't want whitespace before first tag to turn into paragraphs
                    if (![tagName isEqualToString:@"html"])
                    {
                        if ( ([tmpString length] + [tagContents length]) >= maxTextSize)
                        {
                            tagContents = [tagContents substringToIndex:(maxTextSize - [tmpString length])];
                            [tmpString appendString:tagContents];
                            [tmpString appendString:@"..."];
                            break;
                        }
                        else
                        {
                            currentTag.text = tagContents;
                            [tmpString appendString:[currentTag string]];
                        }
                    }
				}
				
			}

            if ( [tmpString length] >= maxTextSize )
                break;
		}
		
	}
    
    // returning the temporary mutable string is faster
	//return [self initWithAttributedString:tmpString];
    return [tmpString autorelease];
}

@end
