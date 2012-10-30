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

NSTimeInterval const kDefaultTimeout = 60;

@interface RZWebServiceRequest()

// redeclaration
@property (strong, nonatomic, readwrite) id convertedData;
@property (strong, nonatomic, readwrite) NSDictionary *responseHeaders;
@property (assign, nonatomic, readwrite) NSInteger statusCode;

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

@end


@implementation RZWebServiceRequest
@synthesize manager = _manager;
@synthesize target = _target;
@synthesize httpMethod = _httpMethod;
@synthesize receivedData = _receivedData;
@synthesize bytesReceived = _bytesReceived;
@synthesize connection = _connection;
@synthesize connectionThread = _connectionThread;
@synthesize backgroundTaskId = _backgroundTaskId;
@synthesize url = _url;
@synthesize redirectedURL = _redirectedURL;
@synthesize delegate  = _delegate;
@synthesize successHandler = _successHandler;
@synthesize failureHandler = _failureHandler;
@synthesize parameters = _parameters;
@synthesize requestBody = _requestBody;
@synthesize bodyType = _bodyType;
@synthesize urlRequest = _urlRequest;
@synthesize expectedResultType = _expectedResultType;
@synthesize responseHeaders = _responseHeaders;
@synthesize statusCode = _statusCode;
@synthesize headers = _headers;
@synthesize userInfo = _userInfo;
@synthesize error = _error;
@synthesize convertedData = _convertedData;
@synthesize targetFileURL = _targetFileURL;
@synthesize copyToTargetAtomically = _copyToTargetAtomically;
@synthesize uploadFileURL = _uploadFileURL;
@synthesize targetFileHandle = _targetFileHandle;
@synthesize atomicTempTargetPath = _atomicTempTargetPath;
@synthesize responseSize = _responseSize;
@synthesize timeoutInterval = _timeoutInterval;
@synthesize timeoutSelector = _timeoutSelector;

@synthesize contentLength = _contentLength;
@synthesize done = _done;
@synthesize finished = _finished;
@synthesize executing = _executing;
@synthesize ignoreCertificateValidity = _ignoreCertificateValidity;

@synthesize preProcessBlocks = _preProcessBlocks;
@synthesize postProcessBlocks = _postProcessBlocks;

@synthesize requestCompletionBlock = _requestCompletionBlock;

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

- (id)initWithApiInfo:(NSDictionary*)apiInfo target:(id)target completion:(RZWebServiceRequestCompletionBlock)completionBlock
{
    return [self initWithApiInfo:apiInfo target:target parameters:nil completion:completionBlock];
}

- (id)initWithApiInfo:(NSDictionary*)apiInfo target:(id)target parameters:(NSDictionary*)parameters completion:(RZWebServiceRequestCompletionBlock)completionBlock
{
    return [self initWithApiInfo:apiInfo target:target parameters:parameters preProcessBlocks:nil postProcessBlocks:nil completion:completionBlock];
}

- (id)initWithApiInfo:(NSDictionary*)apiInfo
               target:(id)target
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
               target:target
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
                      target:target
            preProcessBlocks:nil
           postProcessBlocks:nil
          expectedResultType:expectedResultType
                    bodyType:bodyType
                  parameters:parameters
                  completion:[RZWebServiceRequest completionBlockForTarget:target
                                                           successCallBack:successCallback
                                                           failureCallback:failureCallback]];
    
    self.successHandler = successCallback;
    self.failureHandler = failureCallback;
    
    return self;
}

- (id) initWithURL:(NSURL *)url
        httpMethod:(NSString *)httpMethod
            target:(id)target
expectedResultType:(NSString *)expectedResultType
          bodyType:(NSString *)bodyType
        parameters:(NSDictionary *)parameters
        completion:(RZWebServiceRequestCompletionBlock)completionBlock
{
    return [self initWithURL:url httpMethod:httpMethod target:target preProcessBlocks:nil postProcessBlocks:nil expectedResultType:expectedResultType bodyType:bodyType parameters:parameters completion:completionBlock];
}

- (id) initWithURL:(NSURL *)url
        httpMethod:(NSString *)httpMethod
            target:(id)target
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
        self.target = target;
        self.expectedResultType = expectedResultType;
        self.bodyType = bodyType;
        self.copyToTargetAtomically = NO;
        
        // convert the parameters to a sorted array of parameter objects
        NSArray* sortedKeys = [[parameters allKeys] sortedArrayUsingSelector:@selector(compare:)];
        self.parameters = [NSMutableArray arrayWithCapacity:sortedKeys.count];
        
        for (NSString* key in sortedKeys) {
            id value = [parameters objectForKey:key];
            RZWebServiceRequestParameterType type = RZWebServiceRequestParamterTypeQueryString;
            
            // TODO: Check value's class and change parameter type accordingly
            
            RZWebServiceRequestParamter* parameter = [RZWebServiceRequestParamter parameterWithName:key value:value type:type];
            [self.parameters addObject:parameter];
        }
        
        self.urlRequest = [[NSMutableURLRequest alloc] initWithURL:self.url];
        
        self.preProcessBlocks = [[NSArray alloc] initWithArray:preProcessBlocks copyItems:YES];
        self.postProcessBlocks = [[NSArray alloc] initWithArray:postProcessBlocks copyItems:YES];
        
        self.requestCompletionBlock = completionBlock;
    }
    
    return self;
}

+ (RZWebServiceRequestCompletionBlock)completionBlockForTarget:(id)target
                                               successCallBack:(SEL)successCallback
                                               failureCallback:(SEL)failureCallback
{
    RZWebServiceRequestCompletionBlock compBlock = ^(BOOL succeeded, id data, NSError *error, RZWebServiceRequest *request) {
        if (succeeded)
        {
            NSMethodSignature* signature = [target methodSignatureForSelector:successCallback];
            NSInvocation* invocation = [NSInvocation invocationWithMethodSignature:signature];
            [invocation setTarget:target];
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
            NSMethodSignature* signature = [target methodSignatureForSelector:failureCallback];
            NSInvocation* invocation = [NSInvocation invocationWithMethodSignature:signature];
            [invocation setTarget:target];
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

-(void) setSSLCertificateType:(RZWebServiceRequestSSLTrustType)sslCertificateType WithChallengeBlock:(RZWebServiceRequestSSLChallengeBlock)challengeBlock {
    self.sslTrustType = sslCertificateType;
    self.sslChallengeBlock = challengeBlock;
}


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

        
        // keep track of the current thread
        self.connectionThread = [NSThread currentThread];
        
        self.bytesReceived = 0;
        
        _executing = YES;
        [self didChangeValueForKey:@"isExecuting"];    
        
        self.urlRequest.HTTPMethod = self.httpMethod;
        
        
        // if this is a get request and there are parameters, format them as part of the URL, and reset the URL on the request. 
        if(self.parameters && self.parameters.count > 0)
        {
            if ([self.httpMethod isEqualToString:@"GET"] || [self.httpMethod isEqualToString:@"PUT"] || [self.httpMethod isEqualToString:@"DELETE"]) {
                self.urlRequest.URL = [self.url URLByAddingParameters:self.parameters];
            }
            else if(!self.requestBody && ([self.httpMethod isEqualToString:@"POST"] ))
            {
                // set the post body to the formatted parameters, but not if we already have a body set
                self.urlRequest.HTTPBody = [[NSURL URLQueryStringFromParameters:self.parameters] dataUsingEncoding:NSUTF8StringEncoding];
            }
            
        }
        
        // If there is a request body, try to serialize to type defined in bodyType
        if (self.requestBody && !self.urlRequest.HTTPBody)
        {
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
        }
        
        if (self.uploadFileURL && [self.uploadFileURL isFileURL])
        {
            NSInputStream *fileStream = [NSInputStream inputStreamWithURL:self.uploadFileURL];
            self.urlRequest.HTTPBodyStream = fileStream;
        }
        
        // add the string/string pairs as headers.
        for (id key in self.headers) {
            id value = [self.headers objectForKey:key];
            if ([key isKindOfClass:[NSString class]] && [value isKindOfClass:[NSString class]]) {
                [self.urlRequest setValue:value forHTTPHeaderField:key];
            }

        }
        
        // if the expected type is JSON, we should add a header declaring we accept that type. 
        if ([[self.expectedResultType uppercaseString] isEqualToString:@"JSON"]) {
            [self.urlRequest setValue:@"application/json" forHTTPHeaderField:@"Accept"];
        }
        
        // create and start the connection.
        self.connection = [[NSURLConnection alloc] initWithRequest:self.urlRequest delegate:self startImmediately:YES];
        
        // setup our timeout callback. 
        if(self.timeoutInterval <= 0)
            self.timeoutInterval = kDefaultTimeout;
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

    }
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
    
        if (nil != self.requestCompletionBlock)
        {
            self.requestCompletionBlock(NO, nil, error, self);
        }
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
        
#if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_5_0
        convertedResult = [self.receivedData objectFromJSONData];
        
        //
        // if we're 5.0 or above, use the build in JSON deserialization
        //
#else
        convertedResult = [NSJSONSerialization JSONObjectWithData:self.receivedData options:0 error:&jsonError];
#endif
        
        
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
            
            if ([self.target respondsToSelector:@selector(setProgress:animated:)]) {
                [self.target setProgress:progress animated:YES];
            } else if ([self.target respondsToSelector:@selector(setProgress:withRequest:)]) {
                [self.target setProgress:progress withRequest:self];
            } else if ([self.target respondsToSelector:@selector(setProgress:)])  {
                [self.target setProgress:progress];
            } 

            
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
        if ([self.target respondsToSelector:@selector(setProgress:animated:)]) {
            [self.target setProgress:progress animated:YES];
        } else if ([self.target respondsToSelector:@selector(setProgress:withRequest:)]) {
            [self.target setProgress:progress withRequest:self];
        } else if ([self.target respondsToSelector:@selector(setProgress:)])  {
            [self.target setProgress:progress];
        }
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
                    if (nil != self.requestCompletionBlock)
                    {
                        self.requestCompletionBlock(NO, nil, error, self);
                    }
                }
                
            }
            
            
            if (error == nil)
            {
                // ensure the expected file type is set to "File"
                // In this case, no need to convert
                self.expectedResultType = @"File";
                NSString* path = [self.targetFileURL path];
                self.convertedData = [path dataUsingEncoding:NSUTF8StringEncoding];
                
                if (nil != self.requestCompletionBlock)
                {
                    // ensure the expected file type is set to "File"
                    // In this case, no need to convert - just pass along file url
                    self.expectedResultType = kRZWebserviceDataTypeFile;
                    self.requestCompletionBlock(YES, self.convertedData, nil, self);
                }
            }
           
        }
        else {
            
            // attempt to convert data
            NSError *conversionError = nil;
            if (![self convertDataToExpectedType:&conversionError]){
                self.error = conversionError;
                
                if (nil != self.requestCompletionBlock)
                {
                    self.requestCompletionBlock(NO, nil, conversionError, self);
                }
            }
            else{
                
                if (nil != self.requestCompletionBlock)
                {
                    self.requestCompletionBlock(YES, self.receivedData, nil, self);
                }
            }
        }
        
        self.done = YES;
    }
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
/*
- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace {
    return [protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust];
}


- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    
    if(self.ignoreCertificateValidity &&
       [challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust])
    {
        [challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge];
        
        [challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
    }
    else {
        
        /////////////////////////////////////////////////////////////////////////////////////////////////////
        //
        // Our default implementation as per the doc's description:
        //
        // If the delegate does not implement this method the default implementation is used. 
        // If a valid credential for the request is provided as part of the URL, or is available
        // from the NSURLCredentialStorage the [challenge sender] is sent a 
        // useCredential:forAuthenticationChallenge: with the credential. If the challenge has no credential
        // or the credentials fail to authorize access, then continueWithoutCredentialForAuthenticationChallenge: 
        // is sent to [challenge sender] instead.
        /////////////////////////////////////////////////////////////////////////////////////////////////////
        
        NSURLCredential* credential = nil;
        
        NSURL* url = connection.currentRequest.URL;
        NSString* user = [url user];
        NSString* password = [url password];
        
        if(nil != user && nil != password)
        {
            credential = [[NSURLCredential alloc] initWithUser:user password:password persistence:NSURLCredentialPersistenceNone];
        }
        else {
            credential = [[NSURLCredentialStorage sharedCredentialStorage] defaultCredentialForProtectionSpace:challenge.protectionSpace];
        }
        
        // if there is now a valid credential use it for authentication. Otherwise, continue without authentication
        if(nil != credential)
        {
            [[challenge sender] useCredential:credential forAuthenticationChallenge:challenge];
        }
        else {
            [challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
        }
               
    }
}*/
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
                      allow = NO;
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

@end


@implementation RZWebServiceRequestParamter

@synthesize parameterName = _parameterName;
@synthesize parameterValue = _parameterValue;
@synthesize parameterType = _parameterType;

+ (id)parameterWithName:(NSString*)name value:(id)value type:(RZWebServiceRequestParameterType)type
{
    return [[RZWebServiceRequestParamter alloc] initWithName:name value:value type:type];
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

@end
