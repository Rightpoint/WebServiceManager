//
//  WebServiceRequest.m
//  WebServiceManager
//
//  Created by Craig Spitzkoff on 10/21/11.
//  Copyright (c) 2011 Raizlabs Corporation. All rights reserved.
//

#import "RZWebServiceRequest.h"
#import "RZWebService_NSURL.h"
#import "RZFileManager.h"
#import "RZWebServiceManager.h"
#import "NSString+RZMD5.h"
#import "RZMultipartStream.h"
#import <CommonCrypto/CommonCrypto.h>

#if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_5_0
#import "JSONKit.h"
#endif

NSString *const kURLkey = @"URL";
NSString *const kHTTPMethodKey = @"Method";
NSString *const kExpectedResultTypeKey = @"ExpectedResultType";
NSString *const kBodyTypeKey = @"BodyType";
NSString *const kFailureHandlerKey = @"FailureHandler";
NSString *const kSuccessHandlerKey = @"SuccessHandler";
NSString *const kTimeoutKey = @"Timeout";

NSTimeInterval const kRZWebServiceRequestDefaultTimeout = 60;

@interface RZWebServiceRequest()

// redeclaration
@property (strong, nonatomic, readwrite) id convertedData;
@property (strong, nonatomic, readwrite) NSDictionary *responseHeaders;
@property (assign, nonatomic, readwrite) NSInteger statusCode;

@property (strong, nonatomic) NSArray *completionBlocks;
@property (strong, nonatomic) NSArray *preProcessBlocks;
@property (strong, nonatomic) NSArray *postProcessBlocks;

@property (assign, readwrite) NSUInteger bytesReceived;
@property (strong, nonatomic) NSMutableData* receivedData;
@property (strong, nonatomic) NSURLConnection* connection;
@property (strong, nonatomic) NSThread *connectionThread;
@property (assign, nonatomic) UIBackgroundTaskIdentifier backgroundTaskId;
@property (assign, nonatomic) float responseSize;
@property (assign, nonatomic) long long contentLength;
@property (assign, nonatomic) BOOL done;
@property (assign, nonatomic) BOOL finished;
@property (assign, nonatomic) BOOL executing;

// Generated Completion Block for target, successHandler, and failureHandler
// Note: This is used for backward compatability with the old success/failure callback paradigm
@property (nonatomic, copy) RZWebServiceRequestCompletionBlock fallbackCompletionBlock;

//Needed for SSL Auth Challenges
@property (assign, nonatomic) RZWebServiceRequestSSLTrustType sslTrustType;
@property (nonatomic, copy) RZWebServiceRequestSSLChallengeBlock sslChallengeBlock;

// if the user has chosen to stream to a file, a targetFileHandle will be created
@property (strong, nonatomic) NSFileHandle* targetFileHandle;

// if the user has chosen to copy to the target atomically, this will be the
// temporary path of the file until it is completed downloading. 
@property (strong, nonatomic) NSString* atomicTempTargetPath;

// selector used to trigger timeouts. 
@property (assign, nonatomic) SEL timeoutSelector;

// over-ride the read only redirectedURL property so we can write to it internally 
@property (strong, nonatomic) NSURL* redirectedURL;

// Progress Observers
@property (strong, nonatomic) NSMutableSet *progressObservers;

+ (RZWebServiceRequestCompletionBlock)completionBlockForTarget:(id)target
                                               successCallBack:(SEL)successCallback
                                               failureCallback:(SEL)failureCallback;

-(void) beginOperation;
-(void) cancelOperation;

// report an error to the delegate. 
-(void) reportError:(NSError*)error;

// schedule the next timeout interval.
-(void) scheduleTimeout;

// cancel any scheduled timeout. 
-(void) cancelTimeout;

// utility to convert received data into target format
-(BOOL) convertDataToExpectedType:(NSError**)error;
-(BOOL) convertDataToType:(NSString*)dataType error:(NSError**)error;

// helper methods to continue an SSL challenged request
-(void) continueChallengeWithCredentials:(NSURLAuthenticationChallenge*) challenge;
-(void) continueChallengeWithoutCredentials:(NSURLAuthenticationChallenge *)challenge;

// helper method to make sure completionBlock is called on the main thread
-(void) callCompletionBlockWithSucceeded:(BOOL)succeeded data:(id)data error:(NSError*)error;

@end


@implementation RZWebServiceRequest

-(id) initWithApiInfo:(NSDictionary *)apiInfo target:(id)target
{
    self = [self initWithApiInfo:apiInfo target:target parameters:nil];

    return self;
}

-(id) initWithApiInfo:(NSDictionary *)apiInfo target:(id)target parameters:(NSDictionary*)parameters
{
    NSURL* url = [NSURL URLWithString:[apiInfo objectForKey:kURLkey]];
    NSString* httpMethod = [apiInfo objectForKey:kHTTPMethodKey];
    NSString* expectedResultType = [apiInfo objectForKey:kExpectedResultTypeKey];
    NSString* bodyType = [apiInfo objectForKey:kBodyTypeKey];
    SEL successCallback = NSSelectorFromString([apiInfo objectForKey:kSuccessHandlerKey]);
    SEL failureCallback = NSSelectorFromString([apiInfo objectForKey:kFailureHandlerKey]);
    
    self.timeoutInterval = [[apiInfo objectForKey:kTimeoutKey] doubleValue];
    
    self = [self initWithURL:url
                  httpMethod:httpMethod
                   andTarget:target
             successCallback:successCallback
             failureCallback:failureCallback
          expectedResultType:expectedResultType
                    bodyType:bodyType
               andParameters:parameters];
        
    return self;
}

- (id)initWithApiInfo:(NSDictionary*)apiInfo completion:(RZWebServiceRequestCompletionBlock)completionBlock
{
    return [self initWithApiInfo:apiInfo parameters:nil completion:completionBlock];
}

- (id)initWithApiInfo:(NSDictionary*)apiInfo parameters:(NSDictionary*)parameters completion:(RZWebServiceRequestCompletionBlock)completionBlock
{
    return [self initWithApiInfo:apiInfo parameters:parameters preProcessBlocks:nil postProcessBlocks:nil completion:completionBlock];
}

- (id)initWithApiInfo:(NSDictionary*)apiInfo
           parameters:(NSDictionary*)parameters
     preProcessBlocks:(NSArray*)preProcessBlocks
    postProcessBlocks:(NSArray*)postProcessBlocks
           completion:(RZWebServiceRequestCompletionBlock)completionBlock
{
    NSURL* url = [NSURL URLWithString:[apiInfo objectForKey:kURLkey]];
    NSString* httpMethod = [apiInfo objectForKey:kHTTPMethodKey];
    NSString* expectedResultType = [apiInfo objectForKey:kExpectedResultTypeKey];
    NSString* bodyType = [apiInfo objectForKey:kBodyTypeKey];
    
    self = [self initWithURL:url
           httpMethod:httpMethod
     preProcessBlocks:preProcessBlocks
    postProcessBlocks:postProcessBlocks
   expectedResultType:expectedResultType
             bodyType:bodyType
           parameters:parameters
           completion:completionBlock];
    
    self.timeoutInterval = [[apiInfo objectForKey:kTimeoutKey] doubleValue];
    
    return self;
}

-(id) initWithURL:(NSURL*)url 
       httpMethod:(NSString*)httpMethod
        andTarget:(id)target 
  successCallback:(SEL)successCallback
  failureCallback:(SEL)failureCallback
expectedResultType:(NSString*)expectedResultType
         bodyType:(NSString*)bodyType
    andParameters:(NSDictionary*)parameters
{
    self = [self initWithURL:url
                  httpMethod:httpMethod
            preProcessBlocks:nil
           postProcessBlocks:nil
          expectedResultType:expectedResultType
                    bodyType:bodyType
                  parameters:parameters
                  completion:nil];
    
    self.target = target;
    self.successHandler = successCallback;
    self.failureHandler = failureCallback;
    
    return self;
}

- (id) initWithURL:(NSURL *)url
        httpMethod:(NSString *)httpMethod
expectedResultType:(NSString *)expectedResultType
          bodyType:(NSString *)bodyType
        parameters:(NSDictionary *)parameters
        completion:(RZWebServiceRequestCompletionBlock)completionBlock
{
    return [self initWithURL:url httpMethod:httpMethod preProcessBlocks:nil postProcessBlocks:nil expectedResultType:expectedResultType bodyType:bodyType parameters:parameters completion:completionBlock];
}

- (id) initWithURL:(NSURL *)url
        httpMethod:(NSString *)httpMethod
  preProcessBlocks:(NSArray*)preProcessBlocks
 postProcessBlocks:(NSArray*)postProcessBlocks
expectedResultType:(NSString *)expectedResultType
          bodyType:(NSString *)bodyType
        parameters:(NSDictionary *)parameters
        completion:(RZWebServiceRequestCompletionBlock)completionBlock
{
    self = [super init];
    
    if (nil != self) {
        
        self.backgroundTaskId = UIBackgroundTaskInvalid;
        
        self.url = url;
        self.httpMethod = httpMethod;
        self.expectedResultType = expectedResultType;
        self.bodyType = bodyType;
        self.copyToTargetAtomically = NO;
        self.flattenArrayParameters = NO;
        self.shouldCacheResponse = YES;

        self.parameterMode = RZWebserviceRequestParameterModeDefault;
        self.parameters = [parameters convertToURLEncodedParameters];
        
        self.urlRequest = [[NSMutableURLRequest alloc] initWithURL:self.url];
        
        self.completionBlocks = [[NSArray alloc] initWithArray:@[completionBlock] copyItems:YES];
        self.preProcessBlocks = [[NSArray alloc] initWithArray:preProcessBlocks copyItems:YES];
        self.postProcessBlocks = [[NSArray alloc] initWithArray:postProcessBlocks copyItems:YES];
    }
    
    return self;
}

// Auto-generated by AppCode
- (id)copyWithZone:(NSZone *)zone {
    RZWebServiceRequest *copy = [[[self class] allocWithZone:zone] init];
    
    if (copy != nil) {
        copy.headers = [self.headers copy];
        copy.parameterMode = self.parameterMode;
        copy.parameterArrayDelimiter = [self.parameterArrayDelimiter copy];
        copy.sslTrustType = self.sslTrustType;
        copy.sslChallengeBlock = self.sslChallengeBlock;
        copy.manager = self.manager;
        copy.target = self.target;
        copy.httpMethod = [self.httpMethod copy];
        copy.receivedData = [self.receivedData copy];
        copy.bytesReceived = self.bytesReceived;
        copy.connection = [self.connection copy];
        copy.connectionThread = [self.connectionThread copy];
        copy.backgroundTaskId = self.backgroundTaskId;
        copy.url = [self.url copy];
        copy.redirectedURL = [self.redirectedURL copy];
        copy.successHandler = self.successHandler;
        copy.failureHandler = self.failureHandler;
        copy.parameters = [self.parameters copy];
        copy.requestBody = [self.requestBody copy];
        copy.bodyType = [self.bodyType copy];
        copy.urlRequest = [self.urlRequest copy];
        copy.expectedResultType = [self.expectedResultType copy];
        copy.responseHeaders = [self.responseHeaders copy];
        copy.statusCode = self.statusCode;
        copy.userInfo = [self.userInfo copy];
        copy.error = [self.error copy];
        copy.convertedData = [self.convertedData copy];
        copy.targetFileURL = [self.targetFileURL copy];
        copy.copyToTargetAtomically = self.copyToTargetAtomically;
        copy.uploadFileURL = [self.uploadFileURL copy];
        copy.targetFileHandle = [self.targetFileHandle copy];
        copy.atomicTempTargetPath = [self.atomicTempTargetPath copy];
        copy.responseSize = self.responseSize;
        copy.timeoutInterval = self.timeoutInterval;
        copy.timeoutSelector = self.timeoutSelector;
        copy.contentLength = self.contentLength;
        copy.done = self.done;
        copy.finished = self.finished;
        copy.executing = self.executing;
        copy.ignoreCertificateValidity = self.ignoreCertificateValidity;
        copy.progressObservers = [self.progressObservers copy];
        copy.completionBlocks = [[NSArray alloc] initWithArray:self.completionBlocks copyItems:YES];
        copy.preProcessBlocks = [[NSArray alloc] initWithArray:self.preProcessBlocks copyItems:YES];
        copy.postProcessBlocks = [[NSArray alloc] initWithArray:self.postProcessBlocks copyItems:YES];
        copy.fallbackCompletionBlock = self.fallbackCompletionBlock;
    }
    
    return copy;
}

+ (RZWebServiceRequestCompletionBlock)completionBlockForTarget:(id)target
                                               successCallBack:(SEL)successCallback
                                               failureCallback:(SEL)failureCallback
{
    __block id blockTarget = target;
    RZWebServiceRequestCompletionBlock compBlock = ^(BOOL succeeded, id data, NSError *error, RZWebServiceRequest *request) {
        if (succeeded)
        {
            NSMethodSignature* signature = [blockTarget methodSignatureForSelector:successCallback];
            NSInvocation* invocation = [NSInvocation invocationWithMethodSignature:signature];
            [invocation setTarget:blockTarget];
            [invocation setSelector:successCallback];
            [invocation setArgument:&data atIndex:2];
            [invocation retainArguments];
            
            if (signature.numberOfArguments > 3)
            {
                [invocation setArgument:&request atIndex:3];
            }
            
            [invocation performSelectorOnMainThread:@selector(invoke) withObject:nil waitUntilDone:YES];
        }
        else
        {
            NSMethodSignature* signature = [blockTarget methodSignatureForSelector:failureCallback];
            NSInvocation* invocation = [NSInvocation invocationWithMethodSignature:signature];
            [invocation setTarget:blockTarget];
            [invocation setSelector:failureCallback];
            [invocation setArgument:&error atIndex:2];
            [invocation retainArguments];
            
            if (signature.numberOfArguments > 3)
            {
                [invocation setArgument:&request atIndex:3];
            }
            
            [invocation performSelectorOnMainThread:@selector(invoke) withObject:nil waitUntilDone:YES];
        }
    };
    
    return [compBlock copy];
}

- (RZWebServiceRequestCompletionBlock)fallbackCompletionBlock
{
    if (_fallbackCompletionBlock == nil && self.target != nil && self.successHandler != nil && self.failureHandler != nil)
    {
        _fallbackCompletionBlock = [RZWebServiceRequest completionBlockForTarget:self.target successCallBack:self.successHandler failureCallback:self.failureHandler];
    }
    
    return _fallbackCompletionBlock;
}

- (void)addCompletionBlock:(RZWebServiceRequestCompletionBlock)block
{
    @synchronized(self)
    {
        NSMutableArray *compBlocks = [self.completionBlocks mutableCopy];
        [compBlocks addObject:[block copy]];
        self.completionBlocks = compBlocks;
    }
}

- (void)addPreProcessingBlock:(RZWebServiceRequestPreProcessBlock)block
{
    @synchronized(self)
    {
        NSMutableArray *preBlocks = [self.preProcessBlocks mutableCopy];
        [preBlocks addObject:[block copy]];
        self.preProcessBlocks = preBlocks;
    }
}

- (void)addPostProcessingBlock:(RZWebServiceRequestPostProcessBlock)block
{
    @synchronized(self)
    {
        NSMutableArray *postBlocks = [self.postProcessBlocks mutableCopy];
        [postBlocks addObject:[block copy]];
        self.postProcessBlocks = postBlocks;
    }
}

#pragma mark - Property Overrides

- (void)setTarget:(id)target
{
    self.fallbackCompletionBlock = nil;
    
    _target = target;
}

- (void)setSuccessHandler:(SEL)successHandler
{
    self.fallbackCompletionBlock = nil;
    
    _successHandler = successHandler;
}

- (void)setFailureHandler:(SEL)failureHandler
{
    self.fallbackCompletionBlock = nil;
    
    _failureHandler = failureHandler;
}

- (NSMutableSet*)progressObservers
{
    if (nil == _progressObservers)
    {
        _progressObservers = [NSMutableSet set];
    }
    
    return _progressObservers;
}

// Lazy load default delimiter of +
- (NSString*)parameterArrayDelimiter
{
    if (_parameterArrayDelimiter == nil){
        _parameterArrayDelimiter = kRZWebServiceRequestDefaultQueryParameterArrayDelimiter;
    }
    return _parameterArrayDelimiter;
}

#pragma mark - Header Manipulation Methods

-(void) setValue:(NSString*)value forHTTPHeaderField:(NSString*)headerField
{
    if(nil == value || nil == headerField)
        return;
    
    if(nil == _headers)
        _headers = [NSMutableDictionary dictionaryWithCapacity:1];
    
    [_headers setValue:value forKey:headerField];
}

-(void) setHeaders:(NSDictionary *)headers
{
    _headers = [headers mutableCopy];
}

-(NSDictionary*) headers
{
    if(nil == _headers)
        return nil;

    return  [NSDictionary dictionaryWithDictionary:_headers];
}

#pragma mark - SSL Authentication/Certificate Methods

-(void) setSSLCertificateType:(RZWebServiceRequestSSLTrustType)sslCertificateType WithChallengeBlock:(RZWebServiceRequestSSLChallengeBlock)challengeBlock {
    self.sslTrustType = sslCertificateType;
    self.sslChallengeBlock = challengeBlock;
}

#pragma mark - Progress Observer Methods

- (void)addProgressObserver:(id<RZWebServiceRequestProgressObserver>)observer
{
    NSSet *filteredSet = [self.progressObservers filteredSetUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSValue *evaluatedObject, NSDictionary *bindings) {
        return observer == evaluatedObject.nonretainedObjectValue;
    }]];
    
    if (filteredSet.count == 0)
    {
        NSValue *nonretainedObserver = [NSValue valueWithNonretainedObject:observer];
        [self.progressObservers addObject:nonretainedObserver];
    }
}

- (void)removeProgressObserver:(id<RZWebServiceRequestProgressObserver>)observer
{
    [self.progressObservers filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSValue *evaluatedObject, NSDictionary *bindings) {
        return observer != evaluatedObject.nonretainedObjectValue;
    }]];
}

- (void)removeAllProgressObservers
{
    [self.progressObservers removeAllObjects];
}

- (void)updateProgressObserversWithProgress:(float)progress
{
    __block RZWebServiceRequest *requestSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.progressObservers enumerateObjectsUsingBlock:^(NSValue *obj, BOOL *stop) {
            id<RZWebServiceRequestProgressObserver> observer = obj.nonretainedObjectValue;
            [observer webServiceRequest:requestSelf setProgress:progress];
        }];
    });
}

#pragma mark - File Upload Methods

- (void)setUploadFileURL:(NSURL *)uploadFileURL
{
    if (uploadFileURL)
    {
        NSError *error = nil;
        
        NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[uploadFileURL path] error:&error];
        
        NSNumber *fileSizeNumber = [fileAttributes objectForKey:NSFileSize];
        self.contentLength = [fileSizeNumber longLongValue];
        
        [self setValue:[NSString stringWithFormat:@"%llu", self.contentLength] forHTTPHeaderField:@"Content-Length"];
    }
    else if (_uploadFileURL)
    {
        [_headers removeObjectForKey:@"Content-Length"];
    }
    
    _uploadFileURL = uploadFileURL;
}

#pragma mark - NSOperation Methods

-(void) start
{
    if (self.isCancelled) {
        
        // If it's already been cancelled, mark the operation as finished and don't start the connection.
        [self willChangeValueForKey:@"isFinished"];
        self.finished = YES;
        [self didChangeValueForKey:@"isFinished"];
        return;
    }
    
    [self willChangeValueForKey:@"isExecuting"];
      
    [NSThread detachNewThreadSelector:@selector(beginOperation) toTarget:self withObject:nil];

}

-(void) beginOperation
{
    
    @autoreleasepool {
        
        // start a background task handler
        if ([[UIDevice currentDevice] respondsToSelector:@selector(isMultitaskingSupported)]){
            if ([[UIDevice currentDevice] isMultitaskingSupported]){
                _backgroundTaskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
                    if (_backgroundTaskId != UIBackgroundTaskInvalid){
                        
                        // cleanup the request
                        [self cancel];
                        
                        // report a background timeout error
                        NSError* error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil];
                        [self reportError:error];
                        
                        // end the background task
                        [[UIApplication sharedApplication] endBackgroundTask:_backgroundTaskId];
                        _backgroundTaskId = UIBackgroundTaskInvalid;
                    }
                }];
            }
        }

        
        // Keep track of the current thread
        self.connectionThread = [NSThread currentThread];
        
        self.bytesReceived = 0;
        
        _executing = YES;
        [self didChangeValueForKey:@"isExecuting"];    
                
        
        // --------------- Headers ----------------
        
        self.urlRequest.HTTPMethod = self.httpMethod;
        
        // add the string/string pairs as headers.
        for (id key in self.headers) {
            id value = [self.headers objectForKey:key];
            if ([key isKindOfClass:[NSString class]] && [value isKindOfClass:[NSString class]]) {
                [self.urlRequest setValue:value forHTTPHeaderField:key];
            }
            
        }
        
        // if the expected type is JSON, we should add a header declaring we accept that type.
        if ([[self.expectedResultType uppercaseString] isEqualToString:kRZWebserviceDataTypeJSON]) {
            [self.urlRequest setValue:@"application/json" forHTTPHeaderField:@"Accept"];
        }
        
        
        // ------------ URL Parameters --------------
        
        
        // Put parameters in the URL if the method supports it or if the mode has been overridden
        BOOL hasParameters = (self.parameters && self.parameters.count > 0);
        
        if (hasParameters)
        {
            BOOL methodSupportsURLParams = ([self.httpMethod isEqualToString:@"GET"] || [self.httpMethod isEqualToString:@"PUT"] || [self.httpMethod isEqualToString:@"DELETE"]);
            if ((self.parameterMode == RZWebserviceRequestParameterModeDefault && methodSupportsURLParams) || self.parameterMode == RZWebServiceRequestParameterModeURL) {
                    self.urlRequest.URL = [self.url URLByAddingParameters:self.parameters arrayDelimiter:self.parameterArrayDelimiter flattenArray:self.flattenArrayParameters];
            }
            
        }
    
    
        // --------------- Request Body and File URL Stream ----------------
          
        // Can't have both a body and a body stream. Need to perform mutual exclusion here, file stream takes priority
        if (self.uploadFileURL != nil && [self.uploadFileURL isFileURL])
        {
          NSInputStream *fileStream = [NSInputStream inputStreamWithURL:self.uploadFileURL];
          self.urlRequest.HTTPBodyStream = fileStream;
        }
        // If there is a request body, try to serialize to type defined in bodyType
        else if (self.requestBody != nil)
        {
            // If this is a POST request and there are parameters, put them in the URL. There is a body already defined so we don't want to blow it away.
            // This use case will not likely come up often, and should be well documented in order to be understood.
            if (hasParameters && self.parameterMode == RZWebserviceRequestParameterModeDefault && [self.httpMethod isEqualToString:@"POST"]){
                self.urlRequest.URL = [self.url URLByAddingParameters:self.parameters arrayDelimiter:self.parameterArrayDelimiter flattenArray:self.flattenArrayParameters];
            }
            
            // If no body type is specified, can we make an assumption?
            if (!self.bodyType)
            {
                if ([self.requestBody isKindOfClass:[UIImage class]])
                {
                    self.bodyType = kRZWebserviceDataTypeImage;
                }
                else if ([self.requestBody isKindOfClass:[NSString class]])
                {
                    self.bodyType = kRZWebserviceDataTypeText;
                }
                
                // TODO: check parameters for NSURLs and assume Multipart form post -SB
                
                if (self.bodyType){
                    NSLog(@"[RZWebserviceRequest] No body type specified, assuming %@", self.bodyType);
                }
            }
            
            NSError *bodyError = nil;
            
            // If already converted to NSData, just tack it on
            if ([self.requestBody isKindOfClass:[NSData class]])
            {
                self.urlRequest.HTTPBody = (NSData*)self.requestBody;
            }
            else if ([self.bodyType isEqualToString:kRZWebserviceDataTypeURLEncoded] && [self.requestBody isKindOfClass:[NSDictionary class]]){
                // convert to URL-encoded parameter string
                NSArray *bodyParameters = [(NSDictionary*)self.requestBody convertToURLEncodedParameters];
                self.urlRequest.HTTPBody = [[NSURL URLQueryStringFromParameters:bodyParameters arrayDelimiter:self.parameterArrayDelimiter flattenArray:self.flattenArrayParameters] dataUsingEncoding:NSUTF8StringEncoding];
                [self.urlRequest setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
                
            }
            else if ([self.bodyType isEqualToString:kRZWebserviceDataTypeJSON])
            {
                #if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_5_0
                    if ([self.requestBody isKindOfClass:[NSString class]])
                    {
                        self.urlRequest.HTTPBody = [(NSString*)self.requestBody JSONDataWithOptions:0 includeQuotes:NO error:&bodyError];
                    }
                    else if ([self.requestBody isKindOfClass:[NSArray class]])
                    {
                        self.urlRequest.HTTPBody = [(NSArray*)self.requestBody JSONDataWithOptions:0 error:&bodyError];
                    }
                    else if ([self.requestBody isKindOfClass:[NSDictionary class]])
                    {
                        self.urlRequest.HTTPBody = [(NSDictionary*)self.requestBody JSONDataWithOptions:0 error:&bodyError];
                    }
                #else
                    self.urlRequest.HTTPBody = [NSJSONSerialization dataWithJSONObject:self.requestBody options:0 error:&bodyError];
                #endif
                
                [self.urlRequest setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
            }
            // convert images to PNG
            else if ([self.bodyType isEqualToString:kRZWebserviceDataTypeImage] && [self.requestBody isKindOfClass:[UIImage class]])
            {
                self.urlRequest.HTTPBody = UIImagePNGRepresentation((UIImage*)[self requestBody]);
            }
            // No body type defined, or bodyType == "text", assume it's an NSString
            else if ((!self.bodyType || [self.bodyType isEqualToString:kRZWebserviceDataTypeText]) && [self.requestBody isKindOfClass:[NSString class]])
            {
                self.urlRequest.HTTPBody = [(NSString*)self.requestBody dataUsingEncoding:NSUTF8StringEncoding];
            }
            // TODO: More body types... plist? XML?
            else{

                NSLog(@"[RZWebserviceRequest] Error with request body: could not determine serialization for body contents of class %@ and desired type %@", NSStringFromClass([self.requestBody class]), self.bodyType);
            }
            
            if (!self.urlRequest.HTTPBody || bodyError){
                NSLog(@"[RZWebserviceRequest] Error with request body: %@", bodyError ? [bodyError localizedDescription] : @"failed to convert to NSData");
            }
            else
            {
                [self.urlRequest setValue:[NSString stringWithFormat:@"%u", [self.urlRequest.HTTPBody length]] forHTTPHeaderField:@"Content-Length"];
            }
            
        }
        else if (hasParameters && (self.parameterMode == RZWebServiceRequestParameterModeBody || (self.parameterMode == RZWebserviceRequestParameterModeDefault && [self.httpMethod isEqualToString:@"POST"]))){
            if ([self.bodyType isEqualToString:kRZWebserviceDataTypeMultipart]) {
                // If the body type is multipart and no requestBody, set the body to stream out
                RZMultipartStream* bodyStream = [[RZMultipartStream alloc] initWithParameterArray:[NSArray arrayWithArray:self.parameters]];
                self.urlRequest.HTTPBodyStream = bodyStream;
                
                self.contentLength = bodyStream.contentLength;
                [self.urlRequest setValue: [NSString stringWithFormat:@"multipart/form-data; boundary=%@", bodyStream.stringBoundary] forHTTPHeaderField:@"Content-Type"];
                [self.urlRequest setValue: [NSString stringWithFormat:@"%llu", self.contentLength] forHTTPHeaderField:@"Content-Length"];
            }
            else {
                // If the parameter mode is Body and no requestBody has been set, OR if the parameter mode is default and the HTTP method is POST, add the parameters to the body
                // Currently only support for encoding as URLEncoded parameters - may want to handle serializing to JSON from parameter dict as well
                self.urlRequest.HTTPBody = [[NSURL URLQueryStringFromParameters:self.parameters arrayDelimiter:self.parameterArrayDelimiter flattenArray:self.flattenArrayParameters] dataUsingEncoding:NSUTF8StringEncoding];
                [self.urlRequest setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
            }
        }
        
        // ------------ Perform preprocessing blocks ------------
        
        @synchronized(self)
        {
            for (RZWebServiceRequestPreProcessBlock block in self.preProcessBlocks){
                block(self);
            };
        }
    
        // ------------ Start the HTTP Connection ---------------
        
        
        // create and start the connection.
        self.connection = [[NSURLConnection alloc] initWithRequest:self.urlRequest delegate:self startImmediately:YES];
        
        // setup our timeout callback. 
        if(self.timeoutInterval <= 0)
            self.timeoutInterval = kRZWebServiceRequestDefaultTimeout;
        [self scheduleTimeout];
                
        while (!self.done && !self.isCancelled) {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
        }
        
        @synchronized(self){
            
            // end the background task
            if (_backgroundTaskId != UIBackgroundTaskInvalid){
                [[UIApplication sharedApplication] endBackgroundTask:_backgroundTaskId];
                _backgroundTaskId = UIBackgroundTaskInvalid;
            }
            
            self.connectionThread = nil;
            
            [self willChangeValueForKey:@"isFinished"];
            [self willChangeValueForKey:@"isExecuting"];
            
            _finished = YES;
            _executing = NO;
            
            [self didChangeValueForKey:@"isExecuting"];
            [self didChangeValueForKey:@"isFinished"];
        }
        
    } // @autoreleasepool
}

- (BOOL)isConcurrent {
    return YES;
}

- (BOOL)isExecuting {
    return _executing;
}

- (BOOL)isFinished {
    return _finished;
}

-(void) cancel
{
    if ([NSThread currentThread] != self.connectionThread && self.connectionThread){
        [self performSelector:@selector(cancelOperation) onThread:self.connectionThread withObject:nil waitUntilDone:NO];
    }
    else{
        [self cancelOperation];
    }
}

-(void) cancelOperation
{
    @synchronized(self){
        
        if (self.isFinished) return;
        
        [super cancel];
        [self cancelTimeout];
        [self.connection cancel];
        if (self.targetFileURL && (self.executing || !self.done)) {
            
            [self.targetFileHandle closeFile];
            self.targetFileHandle = nil;
            NSError* error = nil;
            NSString* path = (nil != self.atomicTempTargetPath)  ? self.atomicTempTargetPath : [self.targetFileURL path];
            BOOL isDirectory = YES;
            
            NSFileManager* fileManager = [NSFileManager defaultManager];
            
            // delete the file, but only if it is not a naming conflict with a directory. Do not 
            // delete any matching directories.
            if ([fileManager fileExistsAtPath:path isDirectory:&isDirectory] && !isDirectory) {
                [[NSFileManager defaultManager] removeItemAtPath:path error:&error];
                if (error) {
                    NSLog(@"Error removing %@: %@", path, error);
                }
            }
            
        }
        self.done = YES;
    }
}

-(void) timeout
{
    // TODO: flesh out the userInfo dictionary passed to create the error. 
    NSError* error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil];
    if (self.isFinished) {
        return;
    }
    [self reportError:error];
    
    self.done = YES;
    [self cancel];
}


-(void) cancelTimeout
{
    // if we never assigned the connection thread property, we never will have scheduled a timeout
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
}

-(void) scheduleTimeout
{
    @synchronized(self){
        
        if (self.isCancelled) return;
        
        [self cancelTimeout];
        
        if (nil == self.timeoutSelector) {
            self.timeoutSelector =  @selector(timeout);
        }
        
        [self performSelector:self.timeoutSelector withObject:nil afterDelay:self.timeoutInterval];
    }
}

-(NSData*) data
{
    return [[NSData alloc] initWithData:self.receivedData];
}

-(void) reportError:(NSError*)error
{
    @synchronized(self){
        [self cancelTimeout];
        
        [self callCompletionBlockWithSucceeded:NO data:self.convertedData error:error];
    }
}

- (BOOL)convertDataToExpectedType:(NSError *__autoreleasing *)error
{
    return [self convertDataToType:self.expectedResultType error:error];
}

- (BOOL)convertDataToType:(NSString *)dataType error:(NSError *__autoreleasing *)error
{
    // try to convert the data to the expected type.
    id convertedResult = nil;
    
    if([dataType isEqualToString:kRZWebserviceDataTypeImage])
    {
        convertedResult = [UIImage imageWithData:self.receivedData];
    }
    else if([dataType isEqualToString:kRZWebserviceDataTypeText])
    {
        convertedResult = [[NSString alloc] initWithData:self.receivedData encoding:NSUTF8StringEncoding];
    }
    else if([dataType isEqualToString:kRZWebserviceDataTypeJSON])
    {
        NSError* jsonError = nil;
        
        //If data is nil we cant parse it as JSON or we get a crash
        if (self.receivedData == nil) {
            if (error){
                *error = [NSError errorWithDomain:@"No data returned from server" code:0 userInfo:[NSDictionary dictionaryWithObject:self forKey:@"Request"]];
            }
            return NO;
        }
        
        //
        // if we're supporting anything earlier than 5.0, use JSONKit.
        //
        
        convertedResult = [NSJSONSerialization JSONObjectWithData:self.receivedData options:0 error:&jsonError];        
        
        if (jsonError) {
            NSString* str = [[NSString alloc] initWithData:self.receivedData encoding:NSUTF8StringEncoding];
            NSLog(@"Result from server was not valid JSON: %@", str);
            if (error){
                *error = jsonError;
            }
            return NO;
        }
    }
    else if([self.expectedResultType isEqualToString:kRZWebserviceDataTypePlist])
    {
        NSError* plistError  = nil;
        convertedResult = [NSPropertyListSerialization propertyListWithData:self.receivedData options: NSPropertyListImmutable format:nil error:&plistError];
        
        if(plistError) {
            if (error){
                *error = plistError;
            }
            return NO;
        }
    }
    else
    {
        convertedResult = self.receivedData;
    }
    
    self.convertedData = convertedResult;
    return YES;
}

-(void) callCompletionBlockWithSucceeded:(BOOL)succeeded data:(id)data error:(NSError*)error
{
    @synchronized(self)
    {
        // Call postprocessing blocks.
        for (RZWebServiceRequestPostProcessBlock block in self.postProcessBlocks)
        {
            block(self, &data, &succeeded, &error);
        }
        
        // Call completion block
        if (self.completionBlocks.count > 0)
        {
            dispatch_sync(dispatch_get_main_queue(), ^{
                
                for (RZWebServiceRequestCompletionBlock completion in self.completionBlocks)
                {
                    completion(succeeded, data, error, self);
                }
            });
        }
        else if (self.fallbackCompletionBlock)
        {
            dispatch_sync(dispatch_get_main_queue(), ^{
                self.fallbackCompletionBlock(succeeded, data, error, self);
            });
        }
    }
}

#pragma mark - NSURLConnectionDelegate
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    @synchronized(self){
        
        // convert data anyway in case we got an error response body
        // for now always assume JSON unless the type is text (could be HTML)
        // TODO: This should definitely be made more robust. Perhaps an expected error type?
        //       Or automatic detection of data type (voodoo!)
        if (![self.expectedResultType isEqualToString:kRZWebserviceDataTypeText]){
            [self convertDataToType:kRZWebserviceDataTypeJSON error:NULL];
        }
        else{
            [self convertDataToExpectedType:NULL];
        }
 
                
        self.error = error;
        [self reportError:error];
        self.done = YES;
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    @synchronized(self)
    {
        
        // we received data. reset the timeout. 
        [self scheduleTimeout];
        
        if (!data) return;
        
        self.bytesReceived += data.length;
        
        if (self.targetFileURL) {        
            NSError* error = nil;

            if(nil == self.targetFileHandle)
            {
                
                NSString* path = [self.targetFileURL path];
                
                // if they've chosen to copy to the target atomically,
                // modify the path to a temp directory and a hash of the original
                if (self.copyToTargetAtomically) {
                    NSString* dir = NSTemporaryDirectory();
                    path = [dir stringByAppendingPathComponent:[path digest]];
                    self.atomicTempTargetPath = path;
                }
                
                [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
                
                self.targetFileHandle = [NSFileHandle fileHandleForWritingAtPath:path];
                
                if(nil == self.targetFileHandle)
                {
                    NSLog(@"Error opening file for streaming: %@", error);

                    [self reportError:error];
                
                    self.done = YES;
                    [self cancel];
            
                    return;
                }
            }
            
            [self.targetFileHandle writeData:data];
        }
        
        else 
        {
            
            if (nil == self.receivedData) 
                _receivedData = [[NSMutableData alloc] init];
               
            [self.receivedData appendData:data];
        }
        

        if(self.responseSize > 0)
        {
            float progress = self.bytesReceived / self.responseSize;
            
            [self updateProgressObserversWithProgress:progress];
        }
    }
}

- (void)connection:(NSURLConnection *)connection 
   didSendBodyData:(NSInteger)bytesWritten 
 totalBytesWritten:(NSInteger)totalBytesWritten 
totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite
{
    float progress = -1.0f;
    
    if (totalBytesExpectedToWrite > 0)
    {
        progress = (double)totalBytesWritten / (double)totalBytesExpectedToWrite;
    }
    else if (self.contentLength > 0)
    {
        progress = (double)totalBytesWritten / (double)self.contentLength;
    }
    
    if (progress >= 0.0)
    {
        [self updateProgressObserversWithProgress:progress];
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{    
    @synchronized(self){
        
        [self cancelTimeout];
        
        
        if (self.statusCode >= 400)
        {
            [self cancel];
            
            NSDictionary *errorInfo = [NSDictionary dictionaryWithObject:
                                       [NSString stringWithFormat: NSLocalizedString(@"Server returned status code %d", @""), self.statusCode]
                                                                  forKey:NSLocalizedDescriptionKey];
            NSError *statusError = [NSError errorWithDomain:@"Error"
                                                       code:self.statusCode
                                                   userInfo:errorInfo];
            
            [self connection:connection didFailWithError:statusError];
            return;
        }
        
        if(self.targetFileHandle)
        {
            [self.targetFileHandle closeFile];
            
            NSError* error = nil;
            
            // if we are set to copy the file atomically, we've been streaming
            // to a temporary path. Move the file from the path to the target.
            if (self.copyToTargetAtomically) {
                
                if(![[NSFileManager defaultManager] moveItemAtPath:self.atomicTempTargetPath
                                                        toPath:[self.targetFileURL path]
                                                            error:&error])
                {
                    [self callCompletionBlockWithSucceeded:NO data:nil error:error];
                }
                
            }
            
            
            if (error == nil)
            {
                // ensure the expected file type is set to "File"
                // In this case, no need to convert
                self.expectedResultType = kRZWebserviceDataTypeFile;
                self.convertedData = self.targetFileURL;
                
                [self callCompletionBlockWithSucceeded:YES data:self.convertedData error:nil];
            }
           
        }
        else {
            
            // attempt to convert data
            NSError *conversionError = nil;
            if (![self convertDataToExpectedType:&conversionError]){
                self.error = conversionError;
                
                [self callCompletionBlockWithSucceeded:NO data:nil error:conversionError];
            }
            else{
                
                [self callCompletionBlockWithSucceeded:YES data:self.convertedData error:nil];
            }
        }
        
        self.done = YES;
    }
}

- (NSCachedURLResponse*)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse
{
    return self.shouldCacheResponse ? cachedResponse : nil;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    @synchronized(self){
        
        [self scheduleTimeout];
        
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
            self.responseHeaders = [httpResponse allHeaderFields];
            self.responseSize = [httpResponse expectedContentLength];
            self.statusCode = [httpResponse statusCode];
            
            // allow to continue for error codes, will be handled in didFinishLoading
        }
    }
}

- (NSURLRequest *)connection: (NSURLConnection *)inConnection
             willSendRequest: (NSURLRequest *)inRequest
            redirectResponse: (NSURLResponse *)inRedirectResponse;
{
    @synchronized(self){
        if (inRedirectResponse) {
            NSMutableURLRequest *r = [inRequest mutableCopy]; // original request
            [r setURL: [inRequest URL]];
            
            self.redirectedURL = [inRequest URL];
            
            return r;
        } 
        else {
            return inRequest;
        }
    }
}

- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace {
    @synchronized(self){
        return [protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust];
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
  
    @synchronized(self)
    {
        BOOL shouldContinue = YES;
        BOOL allow = NO;
        
        if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
            NSURLProtectionSpace *protSpace = [challenge protectionSpace];
            SecTrustRef currentServerTrust = [protSpace serverTrust];
            SecTrustResultType trustResult;
            OSStatus err = SecTrustEvaluate(currentServerTrust, &trustResult);
            BOOL trusted = (err == noErr) && ((trustResult == kSecTrustResultProceed) || (trustResult == kSecTrustResultUnspecified));
          
         
            if (trusted)
            {
                allow = YES;
            }
            else
            {
              
              
                //We have an invalid cert, which may be self-signed, expired, or have another error. Lets see if we know how to handle it.
                switch (self.sslTrustType)
                {
                  case RZWebServiceRequestSSLTrustTypeAll:
                      allow = YES;
                      break;
                    
                  case RZWebServiceRequestSSLTrustTypeCA:
                      allow = [self.manager sslCachePermits:challenge];
                      break;
                    
                  case RZWebServiceRequestSSLTrustTypePromptAndCache:
                  {
                    // determine if the challenge leaf certificate's certificate has been
                    // cached. If so, we're allowed to continue.
                    if ([self.manager sslCachePermits:challenge]) {
                      allow = YES;
                      break;
                    }
                    
                    // if it hasn't been cached, this will pass through to the prompt case below.

                  }
                  
                  case RZWebServiceRequestSSLTrustTypePrompt:
                    {
                        // do not continue in this context, since the request will be continued as a result of the block executing.
                        shouldContinue = NO;
                     
                        [self cancelTimeout];
                      
                        self.sslChallengeBlock(challenge, ^(BOOL blockAllow) {
                          
                            if (blockAllow) {
                              
                                // user has allowed the authentication challenege. If the type is set to PromptAndCache, perform caching now.
                                if (self.sslTrustType == RZWebServiceRequestSSLTrustTypePromptAndCache) {
                                    [self.manager cacheAllowedChallenge:challenge];
                                }
                                
                                [self continueChallengeWithCredentials:challenge];
                              
                            }
                            else
                            {
                                [self continueChallengeWithoutCredentials:challenge];
                            }

                            [self scheduleTimeout];
                        });
                    }
                        
                    break;
                    
                    default:
                    {
                        // If we dont set a SSLTrustType we will assume we wont trust self signed certs, unless they have
                        // been previously added to the cache.
                        
                        allow = [self.manager sslCachePermits:challenge];
                    }
                        
                    break;
                }
            }
        }
        else
        {
            allow = NO;
        }
        
        // if the request should continue and will not be continued by another block
        if(shouldContinue)
        {
            if(allow)
            {
                [self continueChallengeWithCredentials:challenge];
            }
            else
            {
                [self continueChallengeWithoutCredentials:challenge];
            }
        }
    }
}

-(void) continueChallengeWithCredentials:(NSURLAuthenticationChallenge*) challenge
{
    [challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge];
}

-(void) continueChallengeWithoutCredentials:(NSURLAuthenticationChallenge *)challenge
{
    [challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
}

- (NSString *)debugDescription {
    return [NSString stringWithFormat:@"%@ - RequestURL:%@ - Parameters:%@ - RequestBody:%@ - DataReturned:%@", [super debugDescription], self.url, self.parameters, self.requestBody, self.convertedData];
}

@end


@implementation RZWebServiceRequestParameter

@synthesize parameterName = _parameterName;
@synthesize parameterValue = _parameterValue;
@synthesize parameterType = _parameterType;

+ (id)parameterWithName:(NSString*)name value:(id)value type:(RZWebServiceRequestParameterType)type
{
    return [[RZWebServiceRequestParameter alloc] initWithName:name value:value type:type];
}

- (id)initWithName:(NSString*)name value:(id)value type:(RZWebServiceRequestParameterType)type
{
    if ((self = [super init]))
    {
        self.parameterName = name;
        self.parameterValue = value;
        self.parameterType = type;
    }
    
    return self;
}

- (unsigned long long)contentLength
{
    unsigned long long contentLength = 0;
    NSDictionary *fileAttributes = nil;
    
    switch (self.parameterType) {
        case RZWebServiceRequestParameterTypeQueryString:
            contentLength = [(NSString*)self.parameterValue dataUsingEncoding:NSUTF8StringEncoding].length;
            break;
        case RZWebServiceRequestParameterTypeFile:
        case RZWebServiceRequestParameterTypeBinaryData:
            fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[(NSURL*)self.parameterValue path] error:nil];
            contentLength = [[fileAttributes objectForKey:NSFileSize] unsignedLongLongValue];
            break;
        default:
            contentLength = 0;
            break;
    }
    
    return contentLength;
}

- (NSString *)debugDescription {
    return [NSString stringWithFormat:@"%@ - Parameter Name:%@ - Parameter Value:%@", [super debugDescription], self.parameterName, self.parameterValue];
}

@end

@implementation NSDictionary (RZWebServiceRequestParameters)

- (NSMutableArray*)convertToURLEncodedParameters
{
    NSArray* sortedKeys = [[self allKeys] sortedArrayUsingSelector:@selector(compare:)];
    NSMutableArray *parameters = [NSMutableArray arrayWithCapacity:sortedKeys.count];
    
    for (NSString* key in sortedKeys)
    {
        id value = [self objectForKey:key];

        // Default to Query String parameter type
        RZWebServiceRequestParameterType type = RZWebServiceRequestParameterTypeQueryString;
        
        if ([value isKindOfClass:[NSURL class]]) {
            type = RZWebServiceRequestParameterTypeFile;
        }
        else if ([value isKindOfClass:[NSData class]]) {
            type = RZWebServiceRequestParameterTypeBinaryData;
        }
     
        RZWebServiceRequestParameter* parameter = [RZWebServiceRequestParameter parameterWithName:key value:value type:type];
        [parameters addObject:parameter];
    }
    
    return parameters;
}

@end
