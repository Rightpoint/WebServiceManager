//
//  WebServiceRequest.m
//  BloomingdalesNYC
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
        self.parameters = parameters;
        
        self.urlRequest = [[NSMutableURLRequest alloc] initWithURL:self.url];
    }
    
    return self;
}

-(void) start
{
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
    
    // create and start the connection.
    self.connection = [[NSURLConnection alloc] initWithRequest:self.urlRequest delegate:self startImmediately:YES];
}

-(void) cancel {
    [self.connection cancel];
}

#pragma mark - NSURLConnectionDelegate
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    if([self.target respondsToSelector:@selector(webServiceRequest:failedWithError:)])
        [self.target webServiceRequest:self failedWithError:error];
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
}

@end
