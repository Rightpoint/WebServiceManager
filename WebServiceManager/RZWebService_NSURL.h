//
//  RZWebService_NSURL.h
//  WebServiceManager
//
//  Created by Craig Spitzkoff on 10/25/11.
//  Copyright (c) 2011 Raizlabs Corporation. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString * const kRZWebServiceRequestDefaultQueryParameterArrayDelimiter;

@interface NSURL (RZWebService_NSURL)

// generate the URL query string for a list or parameters. Default behavior is to URL encode
// the keys and values.
+(NSString*)URLQueryStringFromParameters:(NSArray*)parameters;
+(NSString*)URLQueryStringFromParameters:(NSArray *)parameters encode:(BOOL)encode;
+(NSString*)URLQueryStringFromParameters:(NSArray*)parameters arrayDelimiter:(NSString*)arrayDelimiter;
+(NSString*)URLQueryStringFromParameters:(NSArray *)parameters arrayDelimiter:(NSString*)arrayDelimiter encode:(BOOL)encode;

// return a full url with the parameters query added in.
- (NSURL *)URLByAddingParameters:(NSArray *)parameters arrayDelimiter:(NSString*)arrayDelimiter;

@end
