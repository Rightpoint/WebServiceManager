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

#import "JSONKit.h"

NSString *const kURLkey = @"URL";
NSString *const kHTTPMethodKey = @"Method";
NSString *const kExpectedResultTypeKey = @"ExpectedResultType";
NSString *const kBodyTypeKey = @"BodyType";
NSString *const kFailureHandlerKey = @"FailureHandler";
NSString *const kSuccessHandlerKey = @"SuccessHandler";
NSString *const kTimeoutKey = @"Timeout";

NSTimeInterval const kDefaultTimeout = 60;

@interface RZWebServiceRequest()

@property (strong, nonatomic) NSMutableData* receivedData;
@property (assign, readwrite) NSUInteger bytesReceived;
@property (strong, nonatomic) NSURLConnection* connection;
@property (strong, nonatomic) NSThread *connectionThread;
@property (assign, nonatomic) float responseSize;
@property (assign, nonatomic) long long contentLength;
@property (assign, nonatomic) BOOL done;
@property (assign, nonatomic) BOOL finished;
@property (assign, nonatomic) BOOL executing;

// if the user has chosen to stream to a file, a targetFileHandle will be created
@property (strong, nonatomic) NSFileHandle* targetFileHandle;

// selector used to trigger timeouts. 
@property (assign, nonatomic) SEL timeoutSelector;

// over-ride the read only redirectedURL property so we can write to it internally 
@property (strong, nonatomic) NSURL* redirectedURL;

-(void) beginOperation;
-(void) cancelOperation;

// report an error to the delegate. 
-(void) reportError:(NSError*)error;

// schedule the next timeout interval.
-(void) scheduleTimeout;

// cancel any scheduled timeout. 
-(void) cancelTimeout;

@end


@implementation RZWebServiceRequest
@synthesize target = _target;
@synthesize httpMethod = _httpMethod;
@synthesize receivedData = _receivedData;
@synthesize bytesReceived = _bytesReceived;
@synthesize connection = _connection;
@synthesize connectionThread = _connectionThread;
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
@synthesize targetFileURL = _targetFileURL;
@synthesize uploadFileURL = _uploadFileURL;
@synthesize targetFileHandle = _targetFileHandle;
@synthesize responseSize = _responseSize;
@synthesize timeoutInterval = _timeoutInterval;
@synthesize timeoutSelector = _timeoutSelector;

@synthesize contentLength = _contentLength;
@synthesize done = _done;
@synthesize finished = _finished;
@synthesize executing = _executing;
@synthesize ignoreCertificateValidity = _ignoreCertificateValidity;

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

-(id) initWithURL:(NSURL*)url 
       httpMethod:(NSString*)httpMethod
        andTarget:(id)target 
  successCallback:(SEL)successCallback
  failureCallback:(SEL)failureCallback
expectedResultType:(NSString*)expectedResultType
         bodyType:(NSString*)bodyType
    andParameters:(NSDictionary*)parameters
{
    self = [super init];
    
    if (nil != self) {
        self.url = url;
        self.httpMethod = httpMethod;
        self.target = target;
        self.successHandler = successCallback;
        self.failureHandler = failureCallback;
        self.expectedResultType = expectedResultType;
        self.bodyType = bodyType;

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
    }
    
    return self;
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

- (void)setUploadFileURL:(NSURL *)uploadFileURL
{
    if (uploadFileURL)
    {
        NSError *error = nil;
        
        NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[uploadFileURL path] error:&error];
        
        NSNumber *fileSizeNumber = [fileAttributes objectForKey:NSFileSize];
        self.contentLength = [fileSizeNumber longLongValue];
        
        [self setValue:[NSString stringWithFormat:@"%u", self.contentLength] forHTTPHeaderField:@"Content-Length"];
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
        
        // keep track of the current thread
        self.connectionThread = [NSThread currentThread];
        
        self.bytesReceived = 0;
        
        _executing = YES;
        [self didChangeValueForKey:@"isExecuting"];    
        
        self.urlRequest.HTTPMethod = self.httpMethod;
        
        
        // if this is a get request and there are parameters, format them as part of the URL, and reset the URL on the request. 
        if(self.parameters && self.parameters.count > 0)
        {
            if ([self.httpMethod isEqualToString:@"GET"] || [self.httpMethod isEqualToString:@"PUT"]) {
                self.urlRequest.URL = [self.url URLByAddingParameters:self.parameters];
            }
            else if([self.httpMethod isEqualToString:@"POST"] && !self.requestBody)
            {
                // set the post body to the formatted parameters, but not if we already have a body set
                self.urlRequest.HTTPBody = [[NSURL URLQueryStringFromParameters:self.parameters] dataUsingEncoding:NSUTF8StringEncoding];
            }
            
        }
        
        // If there is a request body, try to serialize to type defined in bodyType
        if (self.requestBody && !self.urlRequest.HTTPBody)
        {
            NSError *bodyError = nil;
            
            // For File/Image assume request body is already serialized to NSData
            if (([self.bodyType isEqualToString:@"File"] || [self.bodyType isEqualToString:@"Image"]) && [self.requestBody isKindOfClass:[NSData class]])
            {
                self.urlRequest.HTTPBody = (NSData*)self.requestBody;
            }
            else if ([self.bodyType isEqualToString:@"JSON"])
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
            
            }
            // No body type defined, or TEXT, assume it's an NSString
            else if ((!self.bodyType || [self.bodyType isEqualToString:@"Text"]) && [self.requestBody isKindOfClass:[NSString class]])
            {
                self.requestBody = [(NSString*)self.requestBody dataUsingEncoding:NSUTF8StringEncoding];
            }
            // TODO: More body types... plist? XML?
            else{

                NSLog(@"Error with request body: could not determine serialization for body class %@ and desired type %@", NSStringFromClass([self.requestBody class]), self.bodyType);
            }
            
            if (bodyError){
                NSLog(@"Error with request body: %@", [bodyError localizedDescription]);
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
            NSString* path = [self.targetFileURL path];
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
    
        if([self.delegate respondsToSelector:@selector(webServiceRequest:failedWithError:)])
            [self.delegate webServiceRequest:self failedWithError:error];    
    }
}

#pragma mark - NSURLConnectionDelegate
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    @synchronized(self){
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
                [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
                self.targetFileHandle = [NSFileHandle fileHandleForWritingToURL:self.targetFileURL error:&error];
                
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
                self.receivedData = [[NSMutableData alloc] init];
               
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
        
        if ([self.delegate respondsToSelector:@selector(webServiceRequest:completedWithData:)]) {
            
            if(self.targetFileHandle)
            {
                [self.targetFileHandle closeFile];
                
                // ensure the expected file type is set to "File"
                self.expectedResultType = @"File";
                NSString* path = [self.targetFileURL path];
                NSData* data = [path dataUsingEncoding:NSUTF8StringEncoding];
                [self.delegate webServiceRequest:self completedWithData:data];
            }
            else {
                [self.delegate webServiceRequest:self completedWithData:self.receivedData];            
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
            
            if (httpResponse.statusCode >= 400)
            {
                [self cancel];
                
                NSDictionary *errorInfo = [NSDictionary dictionaryWithObject:
                                           [NSString stringWithFormat: NSLocalizedString(@"Server returned status code %d", @""), httpResponse.statusCode]
                                                                      forKey:NSLocalizedDescriptionKey];
                NSError *statusError = [NSError errorWithDomain:@"Error"
                                                           code:httpResponse.statusCode   
                                                       userInfo:errorInfo];
                
                [self connection:connection didFailWithError:statusError];
            }

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

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    @synchronized(self){
        if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust])

            [challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge];
        
        [challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
    }
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
