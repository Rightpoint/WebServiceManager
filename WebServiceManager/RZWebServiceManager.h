//
//  WebServiceManager.h
//  WebServiceManager
//
//  Created by Craig Spitzkoff on 10/21/11.
//  Copyright (c) 2011 Raizlabs Corporation. All rights reserved.
//

/** This is the main RZWebServiceManager class. Use this class as one of the 
 possible entry points for interacting with remote web services.
 
 This class can be initialized via a path to a supported plist of API endpoints,
 or via a prepoulated NSDictionary of API calls.
 
 */

#import <Foundation/Foundation.h>
#import "RZWebServiceRequest.h"

extern NSString* const kRZWebserviceDataTypeJSON;
extern NSString* const kRZWebserviceDataTypeFile;
extern NSString* const kRZWebserviceDataTypeText;
extern NSString* const kRZWebserviceDataTypeImage;
extern NSString* const kRZWebserviceDataTypePlist;

@interface RZWebServiceManager : NSObject <WebServiceRequestDelegate>

@property (strong, nonatomic) NSDictionary* apiCalls;
@property (strong, nonatomic) NSString* defaultHost;

///---------------------------------------------------------------------------------------
/// @name Initialization & disposal
///---------------------------------------------------------------------------------------

/** Initializes the RZWebServiceManager with a path to a plist declaring each 
 of the API endpoints.
 
 @param callsPath absolute path to the API plist
 @return Returns the initialized RZWebServiceManager
 */
-(id) initWithCallsPath:(NSString*)callsPath;

/** Initializes the RZWebServiceManager with a dictionary describing the API endpoints.
 
 @param apiCalls dictionary declaring the API endpoints
 @return Returns the initialized RZWebServiceManager
 */
-(id) initWithCalls:(NSDictionary*)apiCalls;

///---------------------------------------------------------------------------------------
/// @name Host Management
///---------------------------------------------------------------------------------------
/** For API endpoints declared without a host, this will set the host used for those
 API calls that occur in the keys array.
 
 @param host Hostname that should be used when calling the referenced APIs
 @param keys Keys of the APIs for which the host should be set

 */
-(void) setHost:(NSString*)host forApiKeys:(NSArray*)keys;

/** For API endpoints declared without a host, this will set the host used for 
 the referenced API key
 
 @param host Hostname that should be used when calling the referenced API
 @param key Key of the API for which the host should be set
 */
-(void) setHost:(NSString*)host forApiKey:(NSString *)key;

///---------------------------------------------------------------------------------------
/// @name Web Request Creation
///---------------------------------------------------------------------------------------
/** Create and automatically enqueue a request based on an API key. 
 
 The key must be perviously loaded by the RZWebServiceManager.
 
 @param key Key that maps to the API for which the RZWebServiceManager will create a request. 
 @param target Target object that will be called upon completion or success of the web request
 depending on the selectors declared in the API declaration. 
 */
-(RZWebServiceRequest*) makeRequestWithKey:(NSString*)key andTarget:(id)target;

/** Create and automatically enqueue a request based on an API key with optional parameters.
 
 The key must be perviously loaded by the RZWebServiceManager. Parameters can be sent in, which will
 be included as part of the body of the HTTP request or as part of the URL, depending 
 on the type of the HTTP request declared for the referenced api key.
 
 @param key Key that maps to the API for which the RZWebServiceManager will create a request.
 @param target Target object that will be called upon completion or success of the web request
 depending on the selectors declared in the API declaration.
 @param parameters Key/Value store of parameters to be sent as part of the HTTP request
 */
-(RZWebServiceRequest*) makeRequestWithKey:(NSString*)key andTarget:(id)target andParameters:(NSDictionary*)parameters;

/** Create a request based on an API key, with the option to enqueue the request.
 
 This request is not automatically enqueued unless the enque flag is set to true. 
 If the enque flag is false, the client will be responsible for enquing the request
 via a call to enqueueRequest. The key must be perviously loaded by the RZWebServiceManager.
 
 @param key Key that maps to the API for which the RZWebServiceManager will create a request.
 @param target Target object that will be called upon completion or success of the web request
 depending on the selectors declared in the API declaration.
 @param enqueue Flag indicating whether to enqueue the request. If false, the calling
 client is responsible for enqueing the request.
 */
-(RZWebServiceRequest*) makeRequestWithKey:(NSString*)key andTarget:(id)target enqueue:(BOOL)enqueue;

/** Create a request based on an API key, while providing input parameters,  with the option to enqueue the request.
 
 This request is not automatically enqueued unless the enque flag is set to true.
 If the enque flag is false, the client will be responsible for enquing the request
 via a call to enqueueRequest. The key must be perviously loaded by the RZWebServiceManager.
 
 Depending on the type of request, parameters will either be sent as URL encoded URL paramers
 or they will be sent as part of the HTTP body for HTTP request types that support it.
 
 @param key Key that maps to the API for which the RZWebServiceManager will create a request.
 @param target Target object that will be called upon completion or success of the web request
 depending on the selectors declared in the API declaration.
 @param parameters Dictionary of string key value pair parameters that will be sent with this request
 @param enqueue Flag indicating whether to enqueue the request. If false, the calling
 client is responsible for enqueing the request.
 */
-(RZWebServiceRequest*) makeRequestWithKey:(NSString*)key andTarget:(id)target andParameters:(NSDictionary*)parameters enqueue:(BOOL)enqueue;

/** Create a request based on an API format key, and the parameters used for substitution in the format key
 
 Using this method, you will be able to provide a key that maps to an API enpoint, when that 
 endpont has been defined using typical objective-c string substitution variables. 
 
 @param target Target object that will be called upon completion or success of the web request
 @param key Key that maps to the API for which the RZWebServiceManager will create a request. The 
 key should point to an enpoint that has URL substitution parameters defined.
 @param ... Additional paramers map to the string susbstitution variables that are defined in the API Endpoint
 */
-(RZWebServiceRequest*) makeRequestWithTarget:(id)target andFormatKey:(NSString*)key, ...;

/** Create a request based on an API format key, and the parameters used for substitution in the format key
 
 Using this method, you will be able to provide a key that maps to an API enpoint, when that
 endpont has been defined using typical objective-c string substitution variables.
 
 @param target Target object that will be called upon completion or success of the web request
 @param parameters Dictionary of string key value pair parameters that will be sent with this request
 @param key Key that maps to the API for which the RZWebServiceManager will create a request. The
 key should point to an enpoint that has URL substitution parameters defined.
 @param ... Additional paramers map to the string susbstitution variables that are defined in the API Endpoint
 */
-(RZWebServiceRequest*) makeRequestWithTarget:(id)target andParameters:(NSDictionary*)parameters andFormatKey:(NSString*)key, ...;


/** Create a request based on an API format key, and the parameters used for substitution in the format key
 
 Using this method, you will be able to provide a key that maps to an API enpoint, when that
 endpont has been defined using typical objective-c string substitution variables.
 
 @param target Target object that will be called upon completion or success of the web request
 @param enqueue Flag indicating whether to enqueue the request. If false, the calling
 client is responsible for enqueing the request.
 @param key Key that maps to the API for which the RZWebServiceManager will create a request. The
 key should point to an enpoint that has URL substitution parameters defined.
 @param ... Additional paramers map to the string susbstitution variables that are defined in the API Endpoint
*/
-(RZWebServiceRequest*) makeRequestWithTarget:(id)target enqueue:(BOOL)enqueue andFormatKey:(NSString*)key, ...;

/** Create a request based on an API format key, and the parameters used for substitution in the format key
 
 Using this method, you will be able to provide a key that maps to an API enpoint, when that
 endpont has been defined using typical objective-c string substitution variables.
 
 @param target Target object that will be called upon completion or success of the web request
 @param parameters Dictionary of string key value pair parameters that will be sent with this request
 @param enqueue Flag indicating whether to enqueue the request. If false, the calling
 client is responsible for enqueing the request.
 @param key Key that maps to the API for which the RZWebServiceManager will create a request. The
 key should point to an enpoint that has URL substitution parameters defined.
 @param ... Additional paramers map to the string susbstitution variables that are defined in the API Endpoint
 */
-(RZWebServiceRequest*) makeRequestWithTarget:(id)target andParameters:(NSDictionary*)parameters enqueue:(BOOL)enqueue andFormatKey:(NSString*)key, ...;

/** Create a request based on an API format key, and the parameters used for substitution in the format key
 
 Using this method, you will be able to provide a key that maps to an API enpoint, when that
 endpont has been defined using typical objective-c string substitution variables.
 
 @param target Target object that will be called upon completion or success of the web request
 @param parameters Dictionary of string key value pair parameters that will be sent with this request
 @param enqueue Flag indicating whether to enqueue the request. If false, the calling
 client is responsible for enqueing the request.
 @param key Key that maps to the API for which the RZWebServiceManager will create a request. The
 key should point to an enpoint that has URL substitution parameters defined.
 @param args Additional paramers map to the string susbstitution variables that are defined in the API Endpoint
 */
-(RZWebServiceRequest*) makeRequestWithTarget:(id)target andParameters:(NSDictionary*)parameters enqueue:(BOOL)enqueue andFormatKey:(NSString*)key arguments:(va_list)args;

/** Create a request with a explicitly defined parameters. 
 
 This methdod creates a request without lookup up predefined API keys in the manager. 
 
 Client must be able to provide the fully formatted URL as well as any parameters. 
 
 @param url URL that this web request will act on
 @param target Target object that will be called upon completion or success of the web request
 @param success Success callback of the format -(void)success:(id)results or -(void)success:(id)results request:(RZWebRequest*)request
 @param failure Failure callback of the format -(void)failure:(NSError*)error or -(void)failure:(NSError*)error request:(RZWebRequest*)request
 @param parameters Dictionary of string key value pair parameters that will be sent with this request
 @param enqueue Flag indicating whether to enqueue the request. If false, the calling
 client is responsible for enqueing the request.
*/
// create requests for the fileManager
-(RZWebServiceRequest*) makeRequestWithURL:(NSURL *)url target:(id)target successCallback:(SEL)success failureCallback:(SEL)failure parameters:(NSDictionary*)parameters enqueue:(BOOL)enqueue;


///---------------------------------------------------------------------------------------
/// @name Enqueing Web Requests
///---------------------------------------------------------------------------------------

/** Enqueue a web request
 
 Add a request to the queue. This will execute the request when there are enough active slots for it.
 
 @param request RZWebServiceRequest object to execute
*/
-(void) enqueueRequest:(RZWebServiceRequest*)request;

/** Enqueue a web request in a specific queue
 
 Add a request to the specified queue. This will execute the request when there are enough active slots for it.
 
 @param request RZWebServiceRequest object to execute
 @param queue Operation queue in which the spcificed request should be enqueued.
 */
-(void) enqueueRequest:(RZWebServiceRequest *)request inQueue:(NSOperationQueue*)queue;

///---------------------------------------------------------------------------------------
/// @name Cancellation of Web Requests
///---------------------------------------------------------------------------------------
/** Cancel any currently queued requests scheduled to call back to a specific target
 
 @param target target object for which we would like to cancel requests. 
 */
-(void) cancelRequestsForTarget:(id)target;

/** Cancel any currently queued requests
 */
-(void) cancelAllRequests;


///---------------------------------------------------------------------------------------
/// @name Concurrency
///---------------------------------------------------------------------------------------

/** Allow for multiple requests to execute concurrently.
 
 @param maxRequests number of request to allow to communicate simultaneously
*/
-(void) setMaximumConcurrentRequests:(NSInteger)maxRequests;

@end
