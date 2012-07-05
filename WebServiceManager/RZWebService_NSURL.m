//
//  WebService_NSURL.m
//  WebServiceManager
//
//  Created by Craig Spitzkoff on 10/25/11.
//  Copyright (c) 2011 Raizlabs Corporation. All rights reserved.
//

#import "RZWebService_NSURL.h"
#import "RZWebServiceRequest.h"

@implementation NSURL (RZWebService_NSURL)

+(NSString*)URLQueryStringFromParameters:(NSArray*)parameters
{
    return [self URLQueryStringFromParameters:parameters encode:YES];
}

+(NSString*)URLQueryStringFromParameters:(NSArray *)parameters encode:(BOOL)encode
{
    NSMutableString* queryString = [NSMutableString stringWithCapacity:100];
    NSArray *queryParameters = [parameters filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"parameterType == %d", RZWebServiceRequestParamterTypeQueryString]];
    
    // sort the keys using default string comparison
    for (NSUInteger parameterIdx = 0; parameterIdx < queryParameters.count; parameterIdx++) {
        
        RZWebServiceRequestParamter* parameter = [queryParameters objectAtIndex:parameterIdx];
        NSString *key = parameter.parameterName;
        id value = parameter.parameterValue;
        
        if(encode && [value isKindOfClass:[NSString class]])
        {
            value = (__bridge_transfer NSString * )CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, 
                                                                                           (__bridge CFStringRef)parameter.parameterValue,
                                                                                           NULL, 
                                                                                           CFSTR(":/?#[]@!$&’()*+,;="),
                                                                                           kCFStringEncodingUTF8);
        }
        
        [queryString appendFormat:@"%@=%@", key, value];
        if (parameterIdx < queryParameters.count - 1) {
            [queryString appendString:@"&"]; // add separator before next parameter
        }
        
    }
    
    return queryString;
}

- (NSURL *)URLByAddingParameters:(NSArray *)parameters {
    
    NSString *parameterString = [NSURL URLQueryStringFromParameters:parameters];
    
    NSMutableString *urlString = [NSMutableString stringWithString:[self absoluteString]];
    
    if (parameterString.length > 0)
    {
        // unless there is already a query add a parameter separator
        if ([self query].length > 0) {
            [urlString appendString:@"&"];
        }
        else {
            [urlString appendString:@"?"];
        }
            
        [urlString appendString:parameterString];
    }
    
    return [NSURL URLWithString:urlString];
    
}

@end
