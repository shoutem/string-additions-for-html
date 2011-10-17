//
//  NSString+HTML+lite.h
//  CoreTextExtensions
//
//  Created by Oliver Drobnik on 1/9/11.
//  Copyright 2011 Drobnik.com. All rights reserved.
//

extern NSString *NSBaseURLDocumentOption;
extern NSString *NSTextEncodingNameDocumentOption;
extern NSString *NSTextSizeMultiplierDocumentOption;

extern NSString *DTMaxImageSize;
extern NSString *DTDefaultTextColor;
extern NSString *DTDefaultLinkColor;

@interface NSString (HTML_lite)

+ (NSString*)stringWithHTMLString:(NSString *)htmlString options:(NSDictionary *)options;

@end
