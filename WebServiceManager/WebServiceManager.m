//
//  WebServiceManager.m
//  BloomingdalesNYC
//
//  Created by Craig Spitzkoff on 10/21/11.
//  Copyright (c) 2011 Raizlabs Corporation. All rights reserved.
//

#import "WebServiceManager.h"
#if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_5_0
#import "JSONKit.h"
#endif

//static NSString* const kWebServiceRoot = @"http://bloomingdales.raizlabs.com/api";

@interface WebServiceManager()

@property (strong, nonatomic) NSMutableArray* requests; 
@property (assign, nonatomic) BOOL requestInProcess;

-(void) startNextRequest;

@end


@implementation WebServiceManager
@synthesize requests = _requests;
@synthesize requestInProcess = _requestInProcess;
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

-(void) enqueueRequest:(WebServiceRequest*)request
{
    if (nil == self.requests) {
        self.requests = [[NSMutableArray alloc] initWithCapacity:10];
    }
    
    request.delegate = self;
    [self.requests addObject:request];
   
    [self startNextRequest];
}

-(WebServiceRequest*) makeRequestWithKey:(NSString*)key andTarget:(id)target
{
    return [self makeRequestWithKey:key andTarget:target andParameters:nil];
}

-(WebServiceRequest*) makeRequestWithKey:(NSString*)key andTarget:(id)target andParameters:(NSDictionary*)parameters {

    NSDictionary* apiCall = [self.apiCalls objectForKey:key];
    
    WebServiceRequest* request = [[WebServiceRequest alloc] initWithApiInfo:apiCall target:target parameters:parameters];
    
    [self enqueueRequest:request];
    
    return request;
}

-(void) cancelRequestsForTarget:(id)target
{
    NSArray* matchingRequests = [self.requests filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"target == %@", target]];     
    for (WebServiceRequest* request in matchingRequests) {
        [request cancel];
    }
}

-(void) startNextRequest
{
    if(!self.requestInProcess) {
        if (self.requests.count > 0) {
            self.requestInProcess = YES;
            WebServiceRequest* request = [self.requests objectAtIndex:0];
            [request start];
        }
        else
        {
            self.requestInProcess = NO;
        }
    }
}
                    
#pragma mark - WebServiceRequestDelegate
-(void) webServiceRequest:(WebServiceRequest*)request failedWithError:(NSError*)error
{
    if(nil != request.failureHandler && [request.target respondsToSelector:request.failureHandler])
    {
        NSMethodSignature* signature = [request.target methodSignatureForSelector:request.failureHandler];
        NSInvocation* invocation = [NSInvocation invocationWithMethodSignature:signature];
        [invocation setTarget:request.target];
        [invocation setSelector:request.failureHandler];
        [invocation setArgument:&error atIndex:2];
        [invocation invoke];            
    }

    [self.requests removeObject:request];
    self.requestInProcess = NO;
    [self startNextRequest];
}

-(void) webServiceRequest:(WebServiceRequest *)request completedWithData:(NSData*)data
{
    if (nil != request.successHandler && [request.target respondsToSelector:request.successHandler]) {
            
            // try to convert the data to the expected type. 
            NSString* expectedDataType = [request.apiInfo objectForKey:kExpectedResultTypeKey];

            id convertedResult = nil;
            
            if([expectedDataType isEqualToString:@"Image"])
            {
                convertedResult = [UIImage imageWithData:data];
            }
            else if([expectedDataType isEqualToString:@"Text"])
            {
                convertedResult = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            }
            else if([expectedDataType isEqualToString:@"JSON"])
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
                    [self webServiceRequest:request failedWithError:jsonError];
                    return;
                }
            }
            else if([expectedDataType isEqualToString:@"PList"])
            {
                NSError* plistError  = nil;
                convertedResult = [NSPropertyListSerialization propertyListWithData:data options: NSPropertyListImmutable format:nil error:&plistError];

                if(plistError) {
                    [self webServiceRequest:request failedWithError:plistError];
                    return;
                }
            }
            
            NSMethodSignature* signature = [request.target methodSignatureForSelector:request.successHandler];
            NSInvocation* invocation = [NSInvocation invocationWithMethodSignature:signature];
            [invocation setTarget:request.target];
            [invocation setSelector:request.successHandler];
            [invocation setArgument:&convertedResult atIndex:2];
            [invocation invoke];
            
        
    }
    
    [self.requests removeObject:request];    
    self.requestInProcess = NO;
    [self startNextRequest];
}

@end
