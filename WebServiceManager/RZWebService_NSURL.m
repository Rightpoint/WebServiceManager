//
//  WebService_NSURL.m
//  WebServiceManager
//
//  Created by Craig Spitzkoff on 10/25/11.
//  Copyright (c) 2011 Raizlabs Corporation. All rights reserved.
//

#import "RZWebService_NSURL.h"

@implementation NSURL (RZWebService_NSURL)

+(NSString*)URLQueryStringFromParameters:(NSDictionary*)parameters
{
    NSMutableString* queryString = [NSMutableString stringWithCapacity:100];
    
    NSArray* keys = [parameters allKeys];
    for(int keyIdx = 0; keyIdx < keys.count; keyIdx++)
    {
        id key = [keys objectAtIndex:keyIdx];
        
        id value = [parameters objectForKey:key];
        
        if([value isKindOfClass:[NSString class]])
        {
            value = (__bridge_transfer NSString * )CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, 
                                                                                                 (__bridge CFStringRef)[parameters valueForKey:key],
                                                                                                 NULL, 
                                                                                                 CFSTR(":/?#[]@!$&’()*+,;="),
                                                                                                 kCFStringEncodingUTF8);
        }
     
        [queryString appendFormat:@"%@=%@", key, value];
        if (keyIdx < keys.count - 1) {
            [queryString appendString:@"&"]; // add separator before next parameter
        }
        
    }
    
    return queryString;

}

- (NSURL *)URLByAddingParameters:(NSDictionary *)parameters {
    
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
