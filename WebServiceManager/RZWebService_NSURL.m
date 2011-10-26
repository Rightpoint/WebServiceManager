//
//  WebService_NSURL.m
//  WebServiceManager
//
//  Created by Craig Spitzkoff on 10/25/11.
//  Copyright (c) 2011 Raizlabs Corporation. All rights reserved.
//

#import "RZWebService_NSURL.h"

@implementation NSURL (RZWebService_NSURL)

- (NSURL *)URLByAddingParameters:(NSDictionary *)parameters {
    
    NSMutableString *urlString = [NSMutableString stringWithString:[self absoluteString]];
    
    // delimiter between each parameter
    NSString* delimiter = @"&";
    
    // start the parameter list with this delimiter...
    NSString* nextDelimiter = @"?";
    
    // unless there is already a query
    if ([self query].length > 0) {
        nextDelimiter = delimiter;
    }
        
    for (id key in parameters)
    {
        
        id value = [parameters valueForKey:key];
        
        // if the value is a string, it may contain characters that need to be escaped. 
        if([value isKindOfClass:[NSString class]])
        {
            value = (__bridge NSString*)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, 
                                                                                (__bridge CFStringRef)[parameters valueForKey:key],
                                                                                NULL, 
                                                                                CFSTR(":/?#[]@!$&’()*+,;="),
                                                                                kCFStringEncodingUTF8);
        }
        
        [urlString appendFormat:@"%@%@=%@",nextDelimiter, key, value];
        
        nextDelimiter = delimiter;
    }
    
    return [NSURL URLWithString:urlString];
    
}
@end
