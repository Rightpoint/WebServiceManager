//
//  WebServiceRequest.m
//  BloomingdalesNYC
//
//  Created by Craig Spitzkoff on 10/21/11.
//  Copyright (c) 2011 Raizlabs Corporation. All rights reserved.
//

#import "WebServiceRequest.h"
#import "WebService_NSURL.h"

NSString *const kURLkey = @"URL";
NSString *const kHTTPMethodKey = @"Method";
NSString *const kExpectedResultTypeKey = @"ExpectedResultType";
NSString *const kFailureHandlerKey = @"FailureHandler";
NSString *const kSuccessHandlerKey = @"SuccessHandler";

@interface WebServiceRequest()

@property (strong, nonatomic) NSMutableData* receivedData;
@property (strong, nonatomic) NSURLConnection* connection;

@end


@implementation WebServiceRequest
@synthesize target = _target;
@synthesize apiInfo = _apiInfo;
@synthesize receivedData = _receivedData;
@synthesize connection = _connection;
@synthesize url = _url;
@synthesize delegate  = _delegate;
@synthesize successHandler = _successHandler;
@synthesize failureHandler = _failureHandler;
@synthesize parameters = _parameters;
@synthesize urlRequest = _urlRequest;

-(id) initWithApiInfo:(NSDictionary *)apiInfo target:(id)target
{
    self = [super init];
    
    _target = target;
    _apiInfo = apiInfo;

    NSString* urlStr = [apiInfo objectForKey:kURLkey];
    self.url = [NSURL URLWithString:urlStr];
    
    self.successHandler = NSSelectorFromString([apiInfo objectForKey:kSuccessHandlerKey]);
    self.failureHandler = NSSelectorFromString([apiInfo objectForKey:kFailureHandlerKey]);
    
    self.urlRequest = [[NSMutableURLRequest alloc] initWithURL:self.url];
    
    return self;
}

-(id) initWithApiInfo:(NSDictionary *)apiInfo target:(id)target parameters:(NSDictionary*)parameters
{
    self = [self initWithApiInfo:apiInfo target:target];

    self.parameters = parameters;
    
    return self;
}

-(void) start
{
    NSString* httpMethod = [self.apiInfo valueForKey:kHTTPMethodKey];
    
    // if this is a get request and there are parameters, format them as part of the URL, and reset the URL on the request. 
    if ([httpMethod isEqualToString:@"GET"] && self.parameters) {
        self.urlRequest.URL = [self.url URLByAddingParameters:self.parameters];
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
