//
//  WebServiceRequest.m
//  WebServiceManager
//
//  Created by Craig Spitzkoff on 10/21/11.
//  Copyright (c) 2011 Raizlabs Corporation. All rights reserved.
//

#import "RZWebServiceRequest.h"
#import "RZWebService_NSURL.h"

NSString *const kURLkey = @"URL";
NSString *const kHTTPMethodKey = @"Method";
NSString *const kExpectedResultTypeKey = @"ExpectedResultType";
NSString *const kFailureHandlerKey = @"FailureHandler";
NSString *const kSuccessHandlerKey = @"SuccessHandler";

@interface RZWebServiceRequest()

@property (strong, nonatomic) NSMutableData* receivedData;
@property (strong, nonatomic) NSURLConnection* connection;
@property (assign, nonatomic) BOOL done;
@property (assign, nonatomic) BOOL finished;
@property (assign, nonatomic) BOOL executing;

-(void) beginOperation;

@end


@implementation RZWebServiceRequest
@synthesize target = _target;
@synthesize httpMethod = _httpMethod;
@synthesize receivedData = _receivedData;
@synthesize connection = _connection;
@synthesize url = _url;
@synthesize delegate  = _delegate;
@synthesize successHandler = _successHandler;
@synthesize failureHandler = _failureHandler;
@synthesize parameters = _parameters;
@synthesize urlRequest = _urlRequest;
@synthesize expectedResultType = _expectedResultType;
@synthesize responseHeaders = _responseHeaders;
@synthesize headers = _headers;
@synthesize userInfo = _userInfo;

@synthesize done = _done;
@synthesize finished = _finished;
@synthesize executing = _executing;

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
    SEL successCallback = NSSelectorFromString([apiInfo objectForKey:kSuccessHandlerKey]);
    SEL failureCallback = NSSelectorFromString([apiInfo objectForKey:kFailureHandlerKey]);
    
    self = [self initWithURL:url
                  httpMethod:httpMethod
                   andTarget:target
             successCallback:successCallback
             failureCallback:failureCallback
          expectedResultType:expectedResultType
               andParameters:parameters];
    
    return self;
}

-(id) initWithURL:(NSURL*)url 
       httpMethod:(NSString*)httpMethod
        andTarget:(id)target 
  successCallback:(SEL)successCallback
  failureCallback:(SEL)failureCallback
expectedResultType:(NSString*)expectedResultType
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

        // convert the parameters to a sorted array of parameter objects
        NSArray* sortedKeys = [[parameters allKeys] sortedArrayUsingSelector:@selector(compare:)];
        self.parameters = [NSMutableArray arrayWithCapacity:sortedKeys.count];

        for (NSString* key in sortedKeys) {
            NSDictionary* parameter = [NSDictionary dictionaryWithObjectsAndKeys:key, kRZURLParameterNameKey, [parameters objectForKey:key], kRZURLParameterValueKey, nil];
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

-(void) start
{
    if (self.isCancelled) {
        
        // If it's already been cancelled, mark the operation as finished.
        [self willChangeValueForKey:@"isFinished"];
        self.finished = YES;
        [self didChangeValueForKey:@"isFinished"];
    }
    
    [self willChangeValueForKey:@"isExecuting"];
      
    [NSThread detachNewThreadSelector:@selector(beginOperation) toTarget:self withObject:nil];

}

-(void) beginOperation
{
    
    @autoreleasepool {
        
        _executing = YES;
        [self didChangeValueForKey:@"isExecuting"];    
        
        self.urlRequest.HTTPMethod = self.httpMethod;
        
        
        // if this is a get request and there are parameters, format them as part of the URL, and reset the URL on the request. 
        if(self.parameters && self.parameters.count > 0)
        {
            if ([self.httpMethod isEqualToString:@"GET"]) {
                self.urlRequest.URL = [self.url URLByAddingParameters:self.parameters];
            }
            else if([self.httpMethod isEqualToString:@"POST"])
            {
                // set the post body to the formatted parameters. 
                self.urlRequest.HTTPBody = [[NSURL URLQueryStringFromParameters:self.parameters] dataUsingEncoding:NSUTF8StringEncoding];
            }
            
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

        
        [self didChangeValueForKey:@"isExecuting"];
        
        while (!self.done) {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
        }
        
        [self willChangeValueForKey:@"isFinished"];
        [self willChangeValueForKey:@"isExecuting"];
        
        _finished = YES;
        _executing = NO;
        
        [self didChangeValueForKey:@"isExecuting"];
        [self didChangeValueForKey:@"isFinished"];

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
    [super cancel];
    [self.connection cancel];
}





#pragma mark - NSURLConnectionDelegate
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    if([self.delegate respondsToSelector:@selector(webServiceRequest:failedWithError:)])
        [self.delegate webServiceRequest:self failedWithError:error];
    
    self.done = YES;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    if (nil == self.receivedData) {
        self.receivedData = [[NSMutableData alloc] init];
    }
    
    [self.receivedData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{    
    if ([self.delegate respondsToSelector:@selector(webServiceRequest:completedWithData:)]) {
        [self.delegate webServiceRequest:self completedWithData:self.receivedData];
    }
    
    self.done = YES;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
        self.responseHeaders = [httpResponse allHeaderFields];
    }
 
}

@end
