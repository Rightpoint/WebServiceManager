//
//  WebServiceManager.h
//  WebServiceManager
//
//  Created by Craig Spitzkoff on 10/21/11.
//  Copyright (c) 2011 Raizlabs Corporation. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RZWebServiceRequest.h"

@interface RZWebServiceManager : NSObject <WebServiceRequestDelegate>

@property (strong, nonatomic) NSDictionary* apiCalls;
@property (strong, nonatomic) NSString* defaultHost;

-(id) initWithCallsPath:(NSString*)callsPath;
-(id) initWithCalls:(NSDictionary*)apiCalls;

-(void) setHost:(NSString*)host forApiKeys:(NSArray*)keys;
-(void) setHost:(NSString*)host forApiKey:(NSString *)key;

// create and automatically enqueue requests
-(RZWebServiceRequest*) makeRequestWithKey:(NSString*)key andTarget:(id)target;
-(RZWebServiceRequest*) makeRequestWithKey:(NSString*)key andTarget:(id)target andParameters:(NSDictionary*)parameters;

// create requests, but do not queue them unless enque flag is true. 
// if Enqueue flag is false, client will be responsible for enquing the request via a call to enqueueRequest
-(RZWebServiceRequest*) makeRequestWithKey:(NSString*)key andTarget:(id)target enqueue:(BOOL)enqueue;
-(RZWebServiceRequest*) makeRequestWithKey:(NSString*)key andTarget:(id)target andParameters:(NSDictionary*)parameters enqueue:(BOOL)enqueue;

// create and automatically enqueue requests with URL format strings
-(RZWebServiceRequest*) makeRequestWithTarget:(id)target andFormatKey:(NSString*)key, ...;
-(RZWebServiceRequest*) makeRequestWithTarget:(id)target andParameters:(NSDictionary*)parameters andFormatKey:(NSString*)key, ...;

// create requests with URL format strings, but do not queue them unless enque flag is true. 
// if Enqueue flag is false, client will be responsible for enquing the request via a call to enqueueRequest
-(RZWebServiceRequest*) makeRequestWithTarget:(id)target enqueue:(BOOL)enqueue andFormatKey:(NSString*)key, ...;
-(RZWebServiceRequest*) makeRequestWithTarget:(id)target andParameters:(NSDictionary*)parameters enqueue:(BOOL)enqueue andFormatKey:(NSString*)key, ...;
-(RZWebServiceRequest*) makeRequestWithTarget:(id)target andParameters:(NSDictionary*)parameters enqueue:(BOOL)enqueue andFormatKey:(NSString*)key arguments:(va_list)args;

// create requests for the fileManager
-(RZWebServiceRequest*) makeRequestWithURL:(NSURL *)url target:(id)target successCallback:(SEL)success failureCallback:(SEL)failure parameters:(NSDictionary*)parameters enqueue:(BOOL)enqueue;

// add a request to the queue. This will execute the request when there are enough active slots for it.
-(void) enqueueRequest:(RZWebServiceRequest*)request;

-(void) cancelRequestsForTarget:(id)target;

// Allow for multiple requests to execute concurrently.
-(void) setMaximumConcurrentRequests:(NSInteger)maxRequests;

@end
