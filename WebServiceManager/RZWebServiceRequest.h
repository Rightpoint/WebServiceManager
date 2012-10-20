//
//  WebServiceRequest.h
//  WebServiceManager
//
//  Created by Craig Spitzkoff on 10/21/11.
//  Copyright (c) 2011 Raizlabs Corporation. All rights reserved.
//

/** The RZWebServiceRequest class represents indivudual web requests that are
 queued up to be sent to their respective endpoints. A request can be created 
 manually or can be created by the RZWebServiceManager which may maintain the 
 master list of valid API enpoints for a given application.
 */
#import <Foundation/Foundation.h>

extern NSString* const kURLkey;
extern NSString* const kHTTPMethodKey;
extern NSString* const kExpectedResultTypeKey;
extern NSString* const kFailureHandlerKey;
extern NSString* const kSuccessHandlerKey;
extern NSString* const kTimeoutKey;

extern NSTimeInterval const kDefaultTimeout; 

@protocol WebServiceRequestDelegate;
@class RZWebServiceManager;

@interface RZWebServiceRequest : NSOperation <NSURLConnectionDataDelegate>
{
@private
    NSMutableDictionary* _headers;
}


///---------------------------------------------------------------------------------------
/// @name Initialization & disposal
///---------------------------------------------------------------------------------------

/** Initializes the RZWebServiceRequest with an apiInfo dictionary and a callback target.
 
 @param apiInfo Dictionary containing api information. 
 @param target for all callback methods deinfed in the apiInfo
 @return Returns a new RZWebServiceRequest object. 
*/
-(id) initWithApiInfo:(NSDictionary*)apiInfo target:(id)target;

/** Initializes the RZWebServiceRequest.
 
 @param apiInfo Dictionary containing api information.
 @param target for all callback methods deinfed in the apiInfo
 @param parameters parameters to be sent to the server as part of the web request. 
 @return Returns a new RZWebServiceRequest object.
 */
-(id) initWithApiInfo:(NSDictionary *)apiInfo target:(id)target parameters:(NSDictionary*)parameters;

/** Initializes the RZWebServiceRequest. 
 
 Initialized the RZWebServiceRequest with explicit parameters instead of pamaters
 being specified as part of a dictionary. 
 
 @param url URL of this web request. 
 @param httpMethod HTTP method of the web request, such as POST, GET, DELETE, PUT, HEAD
 @param target target object that receives callbacks of this web request.
 @param successCallback Success callback that gets executed on the specified target upon successful completion of the web request. 
 @param failureCallback Selector that gets executed on the specified target upon a failed web request. 
 @param expectedResultType Type of data that is expected to be returned from the web service request. Current supported types are:
 - kRZWebserviceDataTypeJSON
 - kRZWebserviceDataTypeFile
 - kRZWebserviceDataTypeText
 - kRZWebserviceDataTypeImage
 - kRZWebserviceDataTypePlist
 @param bodyType Type of data we are sending in this request. Supported types are 
 - kRZWebserviceDataTypeJSON
 - kRZWebserviceDataTypeText
 - kRZWebserviceDataTypeImage
 @param parameters Parameters to be send with this web request
 @return Returns a new RZWebServiceRequest object.
 */
-(id) initWithURL:(NSURL*)url 
       httpMethod:(NSString*)httpMethod
        andTarget:(id)target 
  successCallback:(SEL)successCallback
  failureCallback:(SEL)failureCallback
expectedResultType:(NSString*)expectedResultType
         bodyType:(NSString*)bodyType
    andParameters:(NSDictionary*)parameters;

///---------------------------------------------------------------------------------------
/// @name HTTP Headers
///---------------------------------------------------------------------------------------


/** Set a request header on the outgoing request
 
 @param value value for the header field
 @param headerField Name of the header field.
*/
-(void) setValue:(NSString*)value forHTTPHeaderField:(NSString*)headerField;

///---------------------------------------------------------------------------------------
/// @name Properties
///---------------------------------------------------------------------------------------


/** target that will receive the callbacks */
@property (unsafe_unretained, nonatomic) id target;
/** Success callback selector */
@property (assign, nonatomic) SEL successHandler;
/** Failure callback selector */
@property (assign, nonatomic) SEL failureHandler;
/** Mutable URL request that this RZWebServiceRequest generates. */
@property (strong, nonatomic) NSMutableURLRequest* urlRequest;
/** URL called by this web service  */
@property (strong, nonatomic) NSURL* url;

/** this property is filled in if the request gets redirected. This allows 
 clients to determine the final redirected url */
@property (strong, nonatomic, readonly) NSURL* redirectedURL;

/** HTTP Method used for this request  */
@property (strong, nonatomic) NSString* httpMethod;
/** Data type this web request expects  */
@property (strong, nonatomic) NSString* expectedResultType;
/** field parameters to be sent with this request  */
@property (strong, nonatomic) NSMutableArray* parameters;
/** Body of this web request  */
@property (strong, nonatomic) NSObject* requestBody;
/** Body type of this web request. If not specified the type will try to 
 be inferred from the request body class type */
@property (strong, nonatomic) NSString* bodyType;
/** Arbitrary user data that can be associated with this request. Not sent to the service.   */
@property (strong, nonatomic) NSDictionary* userInfo;
/** timeout interval */
@property (assign, nonatomic) NSTimeInterval timeoutInterval;

/** if you'd like use a file on disk as the request body, set the upload file
 URL that we can stream the body data from. This will override the parameters
 in a POST request's body. */
@property (strong, nonatomic) NSURL *uploadFileURL;


/** Set this to YES if you want to ignore invalid certificates. This is useful
 for testing against self signed SSL certificates or certificates that do not map
 correctly to their hostnames. */
@property (assign, nonatomic) BOOL ignoreCertificateValidity;


/** WebServiceRequestDelegate */
@property (unsafe_unretained, nonatomic) id<WebServiceRequestDelegate> delegate;

///---------------------------------------------------------------------------------------
/// @name Streaming to disk properties
///
/// These properties will be populated when the request completes
///---------------------------------------------------------------------------------------


/** if you'd like to stream to disk, set a target filename where the data
can be saved. This will prevent the data from being kept in memory. */
@property (strong, nonatomic) NSURL* targetFileURL;

/** flag indicating whether we stream directly to the target file or if we 
 move the file after the download is complete. Default is NO. */
@property (assign, nonatomic) BOOL copyToTargetAtomically;

/** request headers to be sent with the request. Only use dictionaries of string/string key value pairs */
@property (strong, nonatomic) NSDictionary* headers;

///---------------------------------------------------------------------------------------
/// @name Completion Properties
///
/// These properties will be populated when the request completes
///---------------------------------------------------------------------------------------

/** error will remain nil if there is no error */
@property (strong, nonatomic) NSError *error;

/** Data converted into the expected format */
@property (strong, nonatomic, readonly) id convertedData;

/** data returned by the web service */
@property (strong, readonly) NSData* data;

/** bytes returned by the web service */
@property (assign, readonly) NSUInteger bytesReceived;

/** Response headers returned from the server */
@property (strong, readonly, nonatomic) NSDictionary* responseHeaders;

/** Status code returned from the server */
@property (assign, readonly, nonatomic) NSInteger statusCode;



@end

/** The WebServiceRequestDelegate protocol facilitates communication between a
 RZWebServiceRequest object and a delegate. Upon completion of the communication 
 with the web service, the failure or completion method below will be called on 
 the delegate
 */
@protocol WebServiceRequestDelegate <NSObject>

/** The web service request failed (may be a connection error or an actual HTTP error code)
 
 @param request RZWebServiceRequest object that is completing
 @param error Error that caused the failure
 */
-(void) webServiceRequest:(RZWebServiceRequest*)request failedWithError:(NSError*)error;

/** The web service request completed successfully
 
 @param request RZWebServiceRequest object that is completing
 @param data Data received by the web service request. If the targetFileURL property
 was set on the RZWebServiceRequest, this argument will contain the path to the downloaded
 and cached data.
 */
-(void) webServiceRequest:(RZWebServiceRequest *)request completedWithData:(NSData*)data;

@end


// Parameter Type Enum
typedef enum {
    RZWebServiceRequestParamterTypeQueryString,                                 // For String and Number parameters that can go in the query string of a URL
    RZWebServiceRequestParamterTypeFile,                                        // For File URL parameters in multi-part form posts
    RZWebServiceRequestParamterTypeBinaryData                                   // For images and other binary data parameters in multi-part form posts
} RZWebServiceRequestParameterType;


/** Parameter object for WebService Requests */
@interface RZWebServiceRequestParamter : NSObject

/** Name of the parameter */
@property (strong, nonatomic) NSString *parameterName;
/** value of the parameter. May be an NSString, NSNumber, etc.  */
@property (strong, nonatomic) id parameterValue;
/** type of parameter being set  */
@property (assign, nonatomic) RZWebServiceRequestParameterType parameterType;

/** create a parameter 
 
 @param name Name of the parameter
 @param value Value of the parameter
 @param type Type of the paramter
 */
+ (id)parameterWithName:(NSString*)name value:(id)value type:(RZWebServiceRequestParameterType)type;

/** Initialize a parameter
 
 @param name Name of the parameter
 @param value Value of the parameter
 @param type Type of the paramter
 */
- (id)initWithName:(NSString*)name value:(id)value type:(RZWebServiceRequestParameterType)type;

@end
