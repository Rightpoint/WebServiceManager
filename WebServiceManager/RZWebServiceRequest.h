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

-(id) initWithApiInfo:(NSDictionary*)apiInfo target:(id)target;
-(id) initWithApiInfo:(NSDictionary *)apiInfo target:(id)target parameters:(NSDictionary*)parameters;

// create a request
-(id) initWithURL:(NSURL*)url 
       httpMethod:(NSString*)httpMethod
        andTarget:(id)target 
  successCallback:(SEL)successCallback
  failureCallback:(SEL)failureCallback
expectedResultType:(NSString*)expectedResultType
         bodyType:(NSString*)bodyType
    andParameters:(NSDictionary*)parameters;

// set a request header on the outgoing request
-(void) setValue:(NSString*)value forHTTPHeaderField:(NSString*)headerField;

@property (unsafe_unretained, nonatomic) id target;
@property (assign, nonatomic) SEL successHandler;
@property (assign, nonatomic) SEL failureHandler;
@property (strong, nonatomic) NSMutableURLRequest* urlRequest;
@property (strong, nonatomic) NSURL* url;

// this property is filled in if the request gets redirected. This allows
// clients to determine the final redirected url
@property (strong, nonatomic, readonly) NSURL* redirectedURL;

@property (strong, nonatomic) NSString* httpMethod;
@property (strong, nonatomic) NSString* expectedResultType;
@property (strong, nonatomic) NSMutableArray* parameters;
@property (strong, nonatomic) NSObject* requestBody;
@property (strong, nonatomic) NSString* bodyType;
@property (strong, nonatomic) NSDictionary* userInfo;

// these properties will be populated when the request completes
// error will remain nil if there is no error
@property (strong, nonatomic) NSError *error;
@property (strong, nonatomic, readonly) id convertedData;

// timeout interval
@property (assign, nonatomic) NSTimeInterval timeoutInterval;

// if you'd like to stream to disk, set a target filename where the data
// can be saved. This will prevent the data from being kept in memory.
@property (strong, nonatomic) NSURL* targetFileURL;

// flag indicating whether we stream directly to the target file or if we
// move the file after the download is complete. Default is NO. 
@property (assign, nonatomic) BOOL copyToTargetAtomically;

// if you'd like use a file on disk as the request body, set the upload file 
// URL that we can stream the body data from. This will override the parameters 
// in a POST request's body.
@property (strong, nonatomic) NSURL *uploadFileURL;

// data returned by the web service
@property (strong, readonly) NSData* data;

// bytes returned by the web service
@property (assign, readonly) NSUInteger bytesReceived;

// request headers to be sent with the request. Only use dictionaries of string/string key value pairs
@property (strong, nonatomic) NSDictionary* headers;

@property (unsafe_unretained, nonatomic) id<WebServiceRequestDelegate> delegate;

// response info
@property (strong, readonly, nonatomic) NSDictionary* responseHeaders;
@property (assign, readonly, nonatomic) NSInteger statusCode;

@property (assign, nonatomic) BOOL ignoreCertificateValidity;

@end


@protocol WebServiceRequestDelegate <NSObject>

-(void) webServiceRequest:(RZWebServiceRequest*)request failedWithError:(NSError*)error;
-(void) webServiceRequest:(RZWebServiceRequest *)request completedWithData:(NSData*)data;

@end


// Parameter Type Enum
typedef enum {
    RZWebServiceRequestParamterTypeQueryString,                                 // For String and Number parameters that can go in the query string of a URL
    RZWebServiceRequestParamterTypeFile,                                        // For File URL parameters in multi-part form posts
    RZWebServiceRequestParamterTypeBinaryData                                   // For images and other binary data parameters in multi-part form posts
} RZWebServiceRequestParameterType;


// Parameter object for WebService Requests
@interface RZWebServiceRequestParamter : NSObject

@property (strong, nonatomic) NSString *parameterName;
@property (strong, nonatomic) id parameterValue;
@property (assign, nonatomic) RZWebServiceRequestParameterType parameterType;

+ (id)parameterWithName:(NSString*)name value:(id)value type:(RZWebServiceRequestParameterType)type;

- (id)initWithName:(NSString*)name value:(id)value type:(RZWebServiceRequestParameterType)type;

@end
