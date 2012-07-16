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

NSString* const kRZWebserviceDataTypeJSON = @"JSON";
NSString* const kRZWebserviceDataTypeFile = @"File";
NSString* const kRZWebserviceDataTypeText = @"Text";
NSString* const kRZWebserviceDataTypeImage = @"Image";
NSString* const kRZWebserviceDataTypePlist = @"Plist";

@interface RZWebServiceManager()

@property (strong, nonatomic) NSOperationQueue* requests; 
@property (strong, nonatomic) NSMutableDictionary* apiSpecificHosts;

-(RZWebServiceRequest*) makeRequestWithApi:(NSDictionary*)apiInfo forKey:(NSString*)apiKey andTarget:(id)target andParameters:(NSDictionary*)parameters enqueue:(BOOL)enqueue;

@end


@implementation RZWebServiceManager
@synthesize requests = _requests;
@synthesize apiCalls = _apiCalls;
@synthesize defaultHost = _defaultHost;
@synthesize apiSpecificHosts = _apiSpecificHosts;

-(id)init{
    if (self = [super init]){
        self.requests = [[NSOperationQueue alloc] init];
        [self.requests setName:@"RZWebServiceManagerQueue"];
        [self.requests setMaxConcurrentOperationCount:1];
    }
    return self;
}

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
        self.apiSpecificHosts = [NSMutableDictionary dictionary];
        
        self.requests = [[NSOperationQueue alloc] init];
        [self.requests setName:@"RZWebServiceManagerQueue"];
        [self.requests setMaxConcurrentOperationCount:1];
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

-(void) setMaximumConcurrentRequests:(NSInteger)maxRequests
{
    self.requests.maxConcurrentOperationCount = maxRequests;
}

-(void) setHost:(NSString*)host forApiKeys:(NSArray*)keys
{
    for (NSString* key in keys) {
        [self setHost:host forApiKey:key];
    }
}

-(void) setHost:(NSString*)host forApiKey:(NSString *)key
{
    if(nil == host) {
        [self.apiSpecificHosts removeObjectForKey:key];
    }
    else {
        [self.apiSpecificHosts setValue:host forKey:key];
    }
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
    
    return [self makeRequestWithApi:apiCall forKey:key andTarget:target andParameters:parameters enqueue:enqueue];
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
    
    return [self makeRequestWithApi:mutableApiCall forKey:key andTarget:target andParameters:parameters enqueue:enqueue];
}

-(RZWebServiceRequest*) makeRequestWithApi:(NSDictionary*)apiInfo forKey:(NSString*)apiKey andTarget:(id)target andParameters:(NSDictionary*)parameters enqueue:(BOOL)enqueue
{
    
    // if there is a default host or a host specific for this API call, and the host has not been specified
    // we may need to mutate the URL, which should otherwise be fully formed at this point 
    NSString* apiSpecificHost = [self.apiSpecificHosts valueForKey:apiKey];
    if(apiSpecificHost || self.defaultHost)
    {
        NSString* host = apiSpecificHost ? apiSpecificHost : self.defaultHost;
        
        NSString* urlString = [apiInfo objectForKey:kURLkey];
        NSURL* url = [NSURL URLWithString:urlString];
        
        if([url host] == nil)
        {
            urlString = [host stringByAppendingString:urlString];
            NSMutableDictionary* mutableApiInfo = [NSMutableDictionary dictionaryWithDictionary:apiInfo];
            [mutableApiInfo setValue:urlString forKey:kURLkey];
            apiInfo = mutableApiInfo;
        }
    }
    
    RZWebServiceRequest* request = [[RZWebServiceRequest alloc] initWithApiInfo:apiInfo target:target parameters:parameters];
    
    if (enqueue)
        [self enqueueRequest:request];
    
    return request;

}

-(RZWebServiceRequest*) makeRequestWithURL:(NSURL *)url target:(id)target successCallback:(SEL)success failureCallback:(SEL)failure parameters:(NSDictionary*)parameters enqueue:(BOOL)enqueue 
{
    RZWebServiceRequest* request = [[RZWebServiceRequest alloc] initWithURL:url httpMethod:@"GET" andTarget:target successCallback:success failureCallback:failure expectedResultType:@"NONE" bodyType:nil andParameters:parameters];
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
            
            if ([request.expectedResultType isEqualToString:kRZWebserviceDataTypeFile]) {
                NSString* path = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                convertedResult = [NSURL fileURLWithPath:path];
            }
            else if([request.expectedResultType isEqualToString:kRZWebserviceDataTypeImage])
            {
                convertedResult = [UIImage imageWithData:data];
            }
            else if([request.expectedResultType isEqualToString:kRZWebserviceDataTypeText])
            {
                convertedResult = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            }
            else if([request.expectedResultType isEqualToString:kRZWebserviceDataTypeJSON])
            {
                NSError* jsonError = nil;
                
                //If data is nil we cant parse it as JSON or we get a crash
                if (data == nil) {
                    NSError* requestError = [NSError errorWithDomain:@"No data returned from server" code:0 userInfo:[NSDictionary dictionaryWithObject:request forKey:@"Request"]];
                    [self webServiceRequest:request failedWithError:requestError];
                    return;
                }
                
                //
                // if we're supporting anything earlier than 5.0, use JSONKit. 
                //
                
                #if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_5_0
                    convertedResult = [data objectFromJSONData];

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
            else if([request.expectedResultType isEqualToString:kRZWebserviceDataTypePlist])
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
