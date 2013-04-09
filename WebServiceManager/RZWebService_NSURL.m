//
//  WebService_NSURL.m
//  WebServiceManager
//
//  Created by Craig Spitzkoff on 10/25/11.
//  Copyright (c) 2011 Raizlabs Corporation. All rights reserved.
//

#import "RZWebService_NSURL.h"
#import "RZWebServiceRequest.h"

NSString * const kRZWebServiceRequestDefaultQueryParameterArrayDelimiter = @"+";

@implementation NSURL (RZWebService_NSURL)

+(NSString*)URLQueryStringFromParameters:(NSArray*)parameters
{
    return [self URLQueryStringFromParameters:parameters arrayDelimiter:kRZWebServiceRequestDefaultQueryParameterArrayDelimiter encode:YES];
}

+(NSString*)URLQueryStringFromParameters:(NSArray *)parameters encode:(BOOL)encode
{
    return [self URLQueryStringFromParameters:parameters arrayDelimiter:kRZWebServiceRequestDefaultQueryParameterArrayDelimiter encode:encode];
}

+(NSString*)URLQueryStringFromParameters:(NSArray*)parameters arrayDelimiter:(NSString*)arrayDelimiter;
{
    return [self URLQueryStringFromParameters:parameters arrayDelimiter:arrayDelimiter encode:YES];
}

+(NSString*)URLQueryStringFromParameters:(NSArray *)parameters arrayDelimiter:(NSString*)arrayDelimiter encode:(BOOL)encode
{
    NSMutableString* queryString = [NSMutableString stringWithCapacity:100];
    NSArray *queryParameters = [parameters filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"parameterType == %d", RZWebServiceRequestParameterTypeQueryString]];
    
    // sort the keys using default string comparison
    for (NSUInteger parameterIdx = 0; parameterIdx < queryParameters.count; parameterIdx++) {
        
        RZWebServiceRequestParameter* parameter = [queryParameters objectAtIndex:parameterIdx];
        NSString *key = parameter.parameterName;
        id value = parameter.parameterValue;
        
        if(encode){
            if([value isKindOfClass:[NSString class]])
            {
                value = (__bridge_transfer NSString * )CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, 
                                                                                               (__bridge CFStringRef)parameter.parameterValue,
                                                                                               NULL, 
                                                                                               CFSTR(":/?#[]@!$&’()*+,;="),
                                                                                               kCFStringEncodingUTF8);
            }
            else if ([value isKindOfClass:[NSArray class]]){
                
                NSMutableString *valueString = [NSMutableString stringWithCapacity:64];
                for (NSUInteger subValueIdx=0; subValueIdx < [(NSArray*)value count]; subValueIdx++){
                    
                    id subValue = [value objectAtIndex:subValueIdx];
                    
                    if ([subValue isKindOfClass:[NSString class]]){
                        subValue = (__bridge_transfer NSString * )CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
                                                                                                          (__bridge CFStringRef)subValue,
                                                                                                          NULL,
                                                                                                          CFSTR(":/?#[]@!$&’()*+,;="),
                                                                                                          kCFStringEncodingUTF8);
                    }
                    
                    [valueString appendFormat:@"%@", subValue];
                    if (subValueIdx != [(NSArray*)value count] - 1){
                        [valueString appendString:arrayDelimiter];
                    }
                }
                
                value = (__bridge_transfer NSString * )CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
                                                                                                     (__bridge CFStringRef)valueString,
                                                                                                     NULL,
                                                                                                     CFSTR(":/?#[]@!$&’()*+,;="),
                                                                                                     kCFStringEncodingUTF8);                
            }
        }
        
        [queryString appendFormat:@"%@=%@", key, value];
        if (parameterIdx < queryParameters.count - 1) {
            [queryString appendString:@"&"]; // add separator before next parameter
        }
        
    }
    
    return queryString;
}

- (NSURL *)URLByAddingParameters:(NSArray *)parameters arrayDelimiter:(NSString *)arrayDelimiter {
    
    NSString *parameterString = [NSURL URLQueryStringFromParameters:parameters arrayDelimiter:arrayDelimiter];
    
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
