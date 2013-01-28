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
#import "RZWebServiceKeychain.h"
#import "NSURLAuthenticationChallenge+Fingerprint.h"

NSString* const kRZWebserviceDataTypeJSON = @"JSON";
NSString* const kRZWebserviceDataTypeFile = @"File";
NSString* const kRZWebserviceDataTypeText = @"Text";
NSString* const kRZWebserviceDataTypeImage = @"Image";
NSString* const kRZWebserviceDataTypePlist = @"Plist";

NSString* const kRZWebserviceCachedCertFingerprints = @"CachedCertFingerprints";

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
        [self requests];
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
        
        [self requests];
    }
    
    return self;
}

- (NSOperationQueue*)requests
{
    if (nil == _requests)
    {
        _requests = [[NSOperationQueue alloc] init];
        [_requests setName:@"RZWebServiceManagerQueue"];
        [_requests setMaxConcurrentOperationCount:1];
    }
    
    return _requests;
}

-(void) enqueueRequest:(RZWebServiceRequest*)request
{
    [self enqueueRequest:request inQueue:self.requests];
}

-(void) enqueueRequest:(RZWebServiceRequest *)request inQueue:(NSOperationQueue*)queue
{
    request.delegate = self;
    request.manager = self;
  
    [queue addOperation:request];
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

-(void) cancelAllRequests
{
    [self.requests cancelAllOperations];
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

-(void) webServiceRequest:(RZWebServiceRequest *)request completedWithData:(id)data
{
    
    if (nil != request.successHandler && [request.target respondsToSelector:request.successHandler]) {
        
            NSMethodSignature* signature = [request.target methodSignatureForSelector:request.successHandler];
            NSInvocation* invocation = [NSInvocation invocationWithMethodSignature:signature];
            [invocation setTarget:request.target];
            [invocation setSelector:request.successHandler];
            [invocation setArgument:&data atIndex:2];
            [invocation retainArguments];
            
            if (signature.numberOfArguments > 3) 
                [invocation setArgument:&request atIndex:3];            
    
            [invocation performSelectorOnMainThread:@selector(invoke) withObject:nil waitUntilDone:NO];
        
    }
    
}

#pragma mark - Certificate Cache
-(BOOL) sslCachePermits:(NSURLAuthenticationChallenge*)challenege
{
    NSNumber* permits = nil;
    
    @synchronized(self)
    {
        NSString* service = [[NSBundle mainBundle] bundleIdentifier];
    
        NSDictionary* cachedCertFingerprints = [RZWebServiceKeychain valueForKey:kRZWebserviceCachedCertFingerprints inService:service];

        permits = [cachedCertFingerprints objectForKey:[challenege sha1Fingerprint]];
    }
    
    return [permits boolValue];
}

-(void) cacheAllowedChallenge:(NSURLAuthenticationChallenge*)challenge
{
    @synchronized(self)
    {
        NSString* service = [[NSBundle mainBundle] bundleIdentifier];
        
        NSMutableDictionary* cachedCertFingerprints = [[RZWebServiceKeychain valueForKey:kRZWebserviceCachedCertFingerprints inService:service] mutableCopy];
        
        if(nil == cachedCertFingerprints) {
            cachedCertFingerprints = [NSMutableDictionary dictionary];
        }
        
        [cachedCertFingerprints setObject:[NSNumber numberWithBool:YES] forKey:[challenge sha1Fingerprint]];
        
        [RZWebServiceKeychain setValue:cachedCertFingerprints forKey:kRZWebserviceCachedCertFingerprints inService:service];
    }
}

-(void) clearSSLCache
{
    @synchronized(self)
    {
        NSString* service = [[NSBundle mainBundle] bundleIdentifier];
        [RZWebServiceKeychain removeValueForKey:kRZWebserviceCachedCertFingerprints inService:service];
    }
}

@end
