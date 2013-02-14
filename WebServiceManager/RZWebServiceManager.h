//
//  WebServiceManager.h
//  WebServiceManager
//
//  Created by Craig Spitzkoff on 10/21/11.
//  Copyright (c) 2011 Raizlabs Corporation. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RZWebServiceRequest.h"

extern NSString* const kRZWebserviceDataTypeJSON;
extern NSString* const kRZWebserviceDataTypeFile;
extern NSString* const kRZWebserviceDataTypeText;
extern NSString* const kRZWebserviceDataTypeImage;
extern NSString* const kRZWebserviceDataTypePlist;
extern NSString* const kRZWebserviceDataTypeMultipart;

@interface RZWebServiceManager : NSObject

@property (strong, nonatomic) NSDictionary* apiCalls;
@property (strong, nonatomic) NSString* defaultHost;

-(id) initWithCallsPath:(NSString*)callsPath;
-(id) initWithCalls:(NSDictionary*)apiCalls;

-(void) setHost:(NSString*)host forApiKeys:(NSArray*)keys;
-(void) setHost:(NSString*)host forApiKey:(NSString *)key;

// create and automatically enqueue requests
- (RZWebServiceRequest*)makeRequestWithKey:(NSString*)key andTarget:(id)target;
- (RZWebServiceRequest*)makeRequestWithKey:(NSString*)key andTarget:(id)target andParameters:(NSDictionary*)parameters;

// create requests, but do not queue them unless enque flag is true. 
// if Enqueue flag is false, client will be responsible for enquing the request via a call to enqueueRequest
- (RZWebServiceRequest*)makeRequestWithKey:(NSString*)key andTarget:(id)target enqueue:(BOOL)enqueue;
- (RZWebServiceRequest*)makeRequestWithKey:(NSString*)key andTarget:(id)target andParameters:(NSDictionary*)parameters enqueue:(BOOL)enqueue;

// create and automatically enqueue requests with URL format strings
- (RZWebServiceRequest*)makeRequestWithTarget:(id)target andFormatKey:(NSString*)key, ...;
- (RZWebServiceRequest*)makeRequestWithTarget:(id)target andParameters:(NSDictionary*)parameters andFormatKey:(NSString*)key, ...;

// create requests with URL format strings, but do not queue them unless enque flag is true. 
// if Enqueue flag is false, client will be responsible for enquing the request via a call to enqueueRequest
- (RZWebServiceRequest*)makeRequestWithTarget:(id)target enqueue:(BOOL)enqueue andFormatKey:(NSString*)key, ...;
- (RZWebServiceRequest*)makeRequestWithTarget:(id)target andParameters:(NSDictionary*)parameters enqueue:(BOOL)enqueue andFormatKey:(NSString*)key, ...;
- (RZWebServiceRequest*)makeRequestWithTarget:(id)target andParameters:(NSDictionary*)parameters enqueue:(BOOL)enqueue andFormatKey:(NSString*)key arguments:(va_list)args;

// create requests for the fileManager
- (RZWebServiceRequest*)makeRequestWithURL:(NSURL *)url target:(id)target successCallback:(SEL)success failureCallback:(SEL)failure parameters:(NSDictionary*)parameters enqueue:(BOOL)enqueue;

// add a request to the queue. This will execute the request when there are enough active slots for it.
-(void) enqueueRequest:(RZWebServiceRequest*)request;
-(void) enqueueRequest:(RZWebServiceRequest*)request inQueue:(NSOperationQueue*)queue;

-(void) cancelRequestsForTarget:(id)target;
-(void) cancelAllRequests;

// Allow for multiple requests to execute concurrently.
-(void) setMaximumConcurrentRequests:(NSInteger)maxRequests;

#pragma mark - SSL Certificate Cache
-(BOOL) sslCachePermits:(NSURLAuthenticationChallenge*)challenege;
-(void) cacheAllowedChallenge:(NSURLAuthenticationChallenge*)challenge;
-(void) clearSSLCache;

@end

@interface RZWebServiceManager (Blocks)

// create and automatically enqueue requests
- (RZWebServiceRequest*)requestWithKey:(NSString*)key completion:(RZWebServiceRequestCompletionBlock)completionBlock;
- (RZWebServiceRequest*)requestWithKey:(NSString*)key parameters:(NSDictionary *)parameters completion:(RZWebServiceRequestCompletionBlock)completionBlock;

// create requests, but do not queue them unless enque flag is true.
// if Enqueue flag is false, client will be responsible for enquing the request via a call to enqueueRequest
- (RZWebServiceRequest*)requestWithKey:(NSString*)key enqueue:(BOOL)enqueue completion:(RZWebServiceRequestCompletionBlock)completionBlock;
- (RZWebServiceRequest*)requestWithKey:(NSString*)key parameters:(NSDictionary*)parameters enqueue:(BOOL)enqueue completion:(RZWebServiceRequestCompletionBlock)completionBlock;

// create and automatically enqueue requests with URL format strings
- (RZWebServiceRequest*)requestWithCompletion:(RZWebServiceRequestCompletionBlock)completionBlock formatKey:(NSString*)key, ...;
- (RZWebServiceRequest*)requestWithParameters:(NSDictionary*)parameters completion:(RZWebServiceRequestCompletionBlock)completionBlock andFormatKey:(NSString*)key, ...;

// create requests with URL format strings, but do not queue them unless enque flag is true.
// if Enqueue flag is false, client will be responsible for enquing the request via a call to enqueueRequest
- (RZWebServiceRequest*)requestWithCompletion:(RZWebServiceRequestCompletionBlock)completionBlock enqueue:(BOOL)enqueue formatKey:(NSString*)key, ...;
- (RZWebServiceRequest*)requestWithParameters:(NSDictionary*)parameters enqueue:(BOOL)enqueue completion:(RZWebServiceRequestCompletionBlock)completionBlock formatKey:(NSString*)key, ...;
- (RZWebServiceRequest*)requestWithParameters:(NSDictionary*)parameters enqueue:(BOOL)enqueue completion:(RZWebServiceRequestCompletionBlock)completionBlock formatKey:(NSString*)key arguments:(va_list)args;

// create requests for the fileManager
- (RZWebServiceRequest*)requestWithURL:(NSURL *)url parameters:(NSDictionary*)parameters enqueue:(BOOL)enqueue completion:(RZWebServiceRequestCompletionBlock)completionBlock;

@end
