//
//  WebService_NSURL.m
//  WebServiceManager
//
//  Created by Craig Spitzkoff on 10/25/11.
//  Copyright (c) 2011 Raizlabs Corporation. All rights reserved.
//

#import "RZWebService_NSURL.h"

NSString *const kRZURLParameterNameKey = @"Name";
NSString *const kRZURLParameterValueKey = @"Value";

@implementation NSURL (RZWebService_NSURL)

+(NSString*)URLQueryStringFromParameters:(NSArray*)parameters
{
    NSMutableString* queryString = [NSMutableString stringWithCapacity:100];
    
    // sort the keys using default string comparison
    for (NSUInteger parameterIdx = 0; parameterIdx < parameters.count; parameterIdx++) {

        NSDictionary* parameter = [parameters objectAtIndex:parameterIdx];
        id key = [parameter objectForKey:kRZURLParameterNameKey];
        id value = [parameter objectForKey:kRZURLParameterValueKey];
        
        if([value isKindOfClass:[NSString class]])
        {
            value = (__bridge_transfer NSString * )CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, 
                                                                                           (__bridge CFStringRef)[parameter objectForKey:kRZURLParameterValueKey],
                                                                                           NULL, 
                                                                                           CFSTR(":/?#[]@!$&’()*+,;="),
                                                                                           kCFStringEncodingUTF8);
        }
        
        [queryString appendFormat:@"%@=%@", key, value];
        if (parameterIdx < parameters.count - 1) {
            [queryString appendString:@"&"]; // add separator before next parameter
        }
    
    }
    
    return queryString;

}

- (NSURL *)URLByAddingParameters:(NSArray *)parameters {
    
    NSMutableString *urlString = [NSMutableString stringWithString:[self absoluteString]];
    
    // unless there is already a query add a parameter separator
    if ([self query].length > 0) {
        [urlString appendString:@"&"];
    }
    else {
        [urlString appendString:@"?"];
    }
        
    [urlString appendString:[NSURL URLQueryStringFromParameters:parameters]];
    
    return [NSURL URLWithString:urlString];
    
}

@end
