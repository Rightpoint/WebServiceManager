//
//  WebServiceRequest.m
//  BloomingdalesNYC
//
//  Created by Craig Spitzkoff on 10/21/11.
//  Copyright (c) 2011 Raizlabs Corporation. All rights reserved.
//

#import "WebServiceRequest.h"

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


-(id) initWithApiInfo:(NSDictionary *)apiInfo target:(id)target
{
    self = [super init];
    
    _target = target;
    _apiInfo = apiInfo;

    NSString* urlStr = [apiInfo objectForKey:kURLkey];
    NSURL* url = [NSURL URLWithString:urlStr];
    
    self.connection = [[NSURLConnection alloc] initWithRequest:[NSURLRequest requestWithURL:url] delegate:self startImmediately:NO];
    
    return self;
}

-(void) start
{
    [self.connection start];
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
