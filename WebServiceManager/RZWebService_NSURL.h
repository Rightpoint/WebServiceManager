//
//  RZWebService_NSURL.h
//  WebServiceManager
//
//  Created by Craig Spitzkoff on 10/25/11.
//  Copyright (c) 2011 Raizlabs Corporation. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString* const kRZURLParameterNameKey;
extern NSString* const kRZURLParameterValueKey;

@interface NSURL (RZWebService_NSURL)

// generate the URL query string for a list or parameters.
+(NSString*)URLQueryStringFromParameters:(NSArray*)parameters;

// return a full url with the parameters query added in.
- (NSURL *)URLByAddingParameters:(NSArray *)parameters;

@end
