//
//  WebServiceManager.m
//  WebServiceManager
//
//  Created by Craig Spitzkoff on 10/21/11.
//  Copyright (c) 2011 Raizlabs Corporation. All rights reserved.
//

#import "RZWebServiceManager.h"
#if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_5_0
#import "JSONKit.h"
#endif

@interface RZWebServiceManager()

@property (strong, nonatomic) NSOperationQueue* requests; 

@end


@implementation RZWebServiceManager
@synthesize requests = _requests;
@synthesize apiCalls = _apiCalls;

-(id) initWithCallsPath:(NSString*)callsPath
{    
    NSDictionary* calls = [NSDictionary dictionaryWithContentsOfFile:callsPath];
    
    self = [self initWithCalls:calls];

    return self;
}

-(id) initWithCalls:(NSDictionary*)apiCalls
{
    self = [super init];
    if (self) {
        self.apiCalls = apiCalls;
    }
    
    return self;
}

-(void) enqueueRequest:(RZWebServiceRequest*)request
{
    if (nil == self.requests) {
        self.requests = [[NSOperationQueue alloc] init];
        [self.requests setName:@"RZWebServiceManagerQueue"];
        [self.requests setMaxConcurrentOperationCount:1];
    }
    
    request.delegate = self;
    [self.requests addOperation:request];
   
}

-(RZWebServiceRequest*) makeRequestWithKey:(NSString*)key andTarget:(id)target
{
    return [self makeRequestWithKey:key andTarget:target andParameters:nil];
}

-(RZWebServiceRequest*) makeRequestWithKey:(NSString*)key andTarget:(id)target andParameters:(NSDictionary*)parameters {

    return [self makeRequestWithKey:key andTarget:target andParameters:parameters enqueue:YES];
}

-(RZWebServiceRequest*) makeRequestWithKey:(NSString*)key andTarget:(id)target enqueue:(BOOL)enqueue
{
    return [self makeRequestWithKey:key andTarget:target andParameters:nil enqueue:enqueue];
}

-(RZWebServiceRequest*) makeRequestWithKey:(NSString*)key andTarget:(id)target andParameters:(NSDictionary*)parameters enqueue:(BOOL)enqueue
{
    NSDictionary* apiCall = [self.apiCalls objectForKey:key];
    
    RZWebServiceRequest* request = [[RZWebServiceRequest alloc] initWithApiInfo:apiCall target:target parameters:parameters];
    
    if (enqueue)
        [self enqueueRequest:request];
    
    return request;
}

-(RZWebServiceRequest*) makeRequestWithTarget:(id)target andFormatKey:(NSString*)key, ...
{
    va_list args;
    va_start(args, key);
    
    RZWebServiceRequest *request = [self makeRequestWithTarget:target andParameters:nil enqueue:YES andFormatKey:key arguments:args];
    
    va_end(args);
    
    return request;
}

-(RZWebServiceRequest*) makeRequestWithTarget:(id)target andParameters:(NSDictionary*)parameters andFormatKey:(NSString*)key, ...
{
    va_list args;
    va_start(args, key);
    
    RZWebServiceRequest *request = [self makeRequestWithTarget:target andParameters:parameters enqueue:YES andFormatKey:key arguments:args];
    
    va_end(args);
    
    return request;
}

-(RZWebServiceRequest*) makeRequestWithTarget:(id)target enqueue:(BOOL)enqueue andFormatKey:(NSString*)key, ...
{
    va_list args;
    va_start(args, key);
    
    RZWebServiceRequest *request = [self makeRequestWithTarget:target andParameters:nil enqueue:enqueue andFormatKey:key arguments:args];
    
    va_end(args);
    
    return request;
}

-(RZWebServiceRequest*) makeRequestWithTarget:(id)target andParameters:(NSDictionary*)parameters enqueue:(BOOL)enqueue andFormatKey:(NSString*)key, ...
{
    va_list args;
    va_start(args, key);
    
    RZWebServiceRequest *request = [self makeRequestWithTarget:target andParameters:parameters enqueue:enqueue andFormatKey:key arguments:args];
    
    va_end(args);
    
    return request;
}

-(RZWebServiceRequest*) makeRequestWithTarget:(id)target andParameters:(NSDictionary*)parameters enqueue:(BOOL)enqueue andFormatKey:(NSString*)key arguments:(va_list)args
{
    NSDictionary *apiCall = [self.apiCalls objectForKey:key];
    
    // Replace URL Format String with completed URL string using passed in args
    NSMutableDictionary *mutableApiCall = [NSMutableDictionary dictionaryWithDictionary:apiCall];
    NSString *apiFormatString = [apiCall objectForKey:kURLkey];
    NSString *apiString = [[NSString alloc] initWithFormat:apiFormatString arguments:args];
    [mutableApiCall setObject:apiString forKey:kURLkey];
    
    RZWebServiceRequest* request = [[RZWebServiceRequest alloc] initWithApiInfo:mutableApiCall target:target parameters:parameters];
    
    if (enqueue)
        [self enqueueRequest:request];
    
    return request;
}

-(void) cancelRequestsForTarget:(id)target
{
    NSArray* matchingRequests = [[self.requests operations] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"target == %@", target]];     
    
    for (RZWebServiceRequest* request in matchingRequests) {
        [request cancel];
    }
}

/*
-(void) startNextRequest
{
    if(!self.requestInProcess) {
        if (self.requests.count > 0) {
            self.requestInProcess = YES;
            RZWebServiceRequest* request = [self.requests objectAtIndex:0];
            [request start];
        }
        else
        {
            self.requestInProcess = NO;
        }
    }
}
 */
                    
#pragma mark - WebServiceRequestDelegate
-(void) webServiceRequest:(RZWebServiceRequest*)request failedWithError:(NSError*)error
{
    if(nil != request.failureHandler && [request.target respondsToSelector:request.failureHandler])
    {
        NSMethodSignature* signature = [request.target methodSignatureForSelector:request.failureHandler];
        NSInvocation* invocation = [NSInvocation invocationWithMethodSignature:signature];
        [invocation setTarget:request.target];
        [invocation setSelector:request.failureHandler];
        [invocation setArgument:&error atIndex:2];
        
        if (signature.numberOfArguments > 3) 
            [invocation setArgument:&request atIndex:3];  
        
        [invocation retainArguments];
        [invocation performSelectorOnMainThread:@selector(invoke) withObject:nil waitUntilDone:NO];
    }

}

-(void) webServiceRequest:(RZWebServiceRequest *)request completedWithData:(NSData*)data
{
    if (nil != request.successHandler && [request.target respondsToSelector:request.successHandler]) {
            
            // try to convert the data to the expected type. 
            id convertedResult = nil;
            
            if ([request.expectedResultType isEqualToString:@"File"]) {
                NSString* path = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                convertedResult = [NSURL fileURLWithPath:path];
            }
            else if([request.expectedResultType isEqualToString:@"Image"])
            {
                convertedResult = [UIImage imageWithData:data];
            }
            else if([request.expectedResultType isEqualToString:@"Text"])
            {
                convertedResult = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            }
            else if([request.expectedResultType isEqualToString:@"JSON"])
            {
                NSError* jsonError = nil;
                
                
                //
                // if we're supporting anything earlier than 5.0, use JSONKit. 
                //
                #if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_5_0
                   convertedResult = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
                //
                // if we're 5.0 or above, use the build in JSON deserialization
                //
                #else   
                    convertedResult = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];  
                #endif
                
                
                if (jsonError) {
                    NSString* str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    NSLog(@"Result from server was not valid JSON: %@", str);
                    
                    [self webServiceRequest:request failedWithError:jsonError];
                    return;
                }
            }
            else if([request.expectedResultType isEqualToString:@"PList"])
            {
                NSError* plistError  = nil;
                convertedResult = [NSPropertyListSerialization propertyListWithData:data options: NSPropertyListImmutable format:nil error:&plistError];

                if(plistError) {
                    [self webServiceRequest:request failedWithError:plistError];
                    return;
                }
            }
            else
            {
                convertedResult = data;
            }
            
            NSMethodSignature* signature = [request.target methodSignatureForSelector:request.successHandler];
            NSInvocation* invocation = [NSInvocation invocationWithMethodSignature:signature];
            [invocation setTarget:request.target];
            [invocation setSelector:request.successHandler];
            [invocation setArgument:&convertedResult atIndex:2];
            [invocation retainArguments];
            
            if (signature.numberOfArguments > 3) 
                [invocation setArgument:&request atIndex:3];            
    
            [invocation performSelectorOnMainThread:@selector(invoke) withObject:nil waitUntilDone:NO];
        
    }
    
}

@end
