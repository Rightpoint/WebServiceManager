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
    return [self URLQueryStringFromParameters:parameters arrayDelimiter:kRZWebServiceRequestDefaultQueryParameterArrayDelimiter flattenArray:NO encode:YES];
}

+(NSString*)URLQueryStringFromParameters:(NSArray*)parameters flattenArray:(BOOL)flattenArray
{
    return [self URLQueryStringFromParameters:parameters arrayDelimiter:kRZWebServiceRequestDefaultQueryParameterArrayDelimiter flattenArray:flattenArray encode:YES];
}

+(NSString*)URLQueryStringFromParameters:(NSArray *)parameters encode:(BOOL)encode
{
    return [self URLQueryStringFromParameters:parameters arrayDelimiter:kRZWebServiceRequestDefaultQueryParameterArrayDelimiter flattenArray:NO encode:encode];
}

+(NSString*)URLQueryStringFromParameters:(NSArray*)parameters arrayDelimiter:(NSString*)arrayDelimiter flattenArray:(BOOL)flattenArray;
{
    return [self URLQueryStringFromParameters:parameters arrayDelimiter:arrayDelimiter flattenArray:flattenArray encode:YES];
}

+(NSString*)URLQueryStringFromParameters:(NSArray *)parameters arrayDelimiter:(NSString*)arrayDelimiter flattenArray:(BOOL)flattenArray encode:(BOOL)encode
{
    NSMutableString* queryString = [NSMutableString stringWithCapacity:100];
    NSArray *queryParameters = [parameters filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"parameterType == %d", RZWebServiceRequestParameterTypeQueryString]];
    
    // sort the keys using default string comparison
    for (NSUInteger parameterIdx = 0; parameterIdx < queryParameters.count; parameterIdx++) {
        
        RZWebServiceRequestParameter* parameter = [queryParameters objectAtIndex:parameterIdx];
        NSString *key = parameter.parameterName;
        id value = parameter.parameterValue;
        BOOL appendKey = YES;
        
        if(encode){
            if([value isKindOfClass:[NSString class]])
            {
                value = (__bridge_transfer NSString * )CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, 
                                                                                               (__bridge CFStringRef)parameter.parameterValue,
                                                                                               NULL, 
                                                                                               CFSTR(":/?#[]@!$&’()*+,;="),
                                                                                               kCFStringEncodingUTF8);
            }
            else if ([value isKindOfClass:[NSArray class]])
            {
                NSMutableString *valueString = [NSMutableString stringWithCapacity:64];
                // If the data is an array type, the key will be added into the value string
                appendKey = !flattenArray;
                
                // Escape the delimiter if it's not a legal URL character already
                arrayDelimiter = (__bridge_transfer NSString * )CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
                                                                                                        (__bridge CFStringRef)arrayDelimiter,
                                                                                                        NULL,
                                                                                                        NULL,
                                                                                                        kCFStringEncodingUTF8);
                

                    for (NSUInteger subValueIdx=0; subValueIdx < [(NSArray*)value count]; subValueIdx++)
                    {
                        id subValue = [value objectAtIndex:subValueIdx];
                        
                        if ([subValue isKindOfClass:[NSString class]]){
                            subValue = (__bridge_transfer NSString * )CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
                                                                                                              (__bridge CFStringRef)subValue,
                                                                                                              NULL,
                                                                                                              CFSTR(":/?#[]@!$&’()*+,;="),
                                                                                                              kCFStringEncodingUTF8);
                        }
                        
                        // Produce a key:value pair for each value with the same key
                        if (flattenArray) {
                            [valueString appendFormat:@"%@=%@", key, subValue];
                            if (subValueIdx != [(NSArray*)value count] - 1){
                                [valueString appendString:@"&"];
                            }
                        }
                        // Concatenate all array values with the array delimeter
                        else {
                            [valueString appendFormat:@"%@", subValue];
                            if (subValueIdx != [(NSArray*)value count] - 1){
                                [valueString appendString:arrayDelimiter];
                            }
                        }
                    }
                value = valueString;
            }
        }
        
        if (appendKey) {
            [queryString appendFormat:@"%@=%@", key, value];
        }
        else {
            [queryString appendString:value];
        }
        
        if (parameterIdx < queryParameters.count - 1) {
            [queryString appendString:@"&"]; // add separator before next parameter
        }
        
    }
    
    return queryString;
}

- (NSURL *)URLByAddingParameters:(NSArray *)parameters arrayDelimiter:(NSString *)arrayDelimiter flattenArray:(BOOL)flattenArray
{    
    NSString *parameterString = [NSURL URLQueryStringFromParameters:parameters arrayDelimiter:arrayDelimiter flattenArray:flattenArray];
    
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
