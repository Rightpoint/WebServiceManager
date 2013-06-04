//
//  WebServiceRequest.h
//  WebServiceManager
//
//  Created by Craig Spitzkoff on 10/21/11.
//  Copyright (c) 2011 Raizlabs Corporation. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString* const kURLkey;
extern NSString* const kHTTPMethodKey;
extern NSString* const kExpectedResultTypeKey;
extern NSString* const kFailureHandlerKey;
extern NSString* const kSuccessHandlerKey;
extern NSString* const kTimeoutKey;

extern NSTimeInterval const kDefaultTimeout;

@class RZWebServiceRequest;
@class RZWebServiceManager;
@protocol RZWebServiceRequestProgressObserver;

typedef void (^RZWebServiceRequestCompletionBlock)(BOOL succeeded, id data, NSError *error, RZWebServiceRequest *request);
typedef void (^RZWebServiceRequestPreProcessBlock)(RZWebServiceRequest *request);
typedef void (^RZWebServiceRequestPostProcessBlock)(RZWebServiceRequest *request, __autoreleasing id* data, BOOL* succeeded, __autoreleasing NSError** error);

typedef void (^RZWebServiceRequestSSLChallengeCompletionBlock)(BOOL allow);
typedef void (^RZWebServiceRequestSSLChallengeBlock)(NSURLAuthenticationChallenge* challenge, RZWebServiceRequestSSLChallengeCompletionBlock completion);

// SSL cert trust type.
typedef enum {
    RZWebServiceRequestSSLTrustTypeCA = 0, // Trust only valid certificates
    RZWebServiceRequestSSLTrustTypeAll,    // trust all certificates, despite validation issues
    RZWebServiceRequestSSLTrustTypePrompt,  // prompt the user on invalid certificates
    RZWebServiceRequestSSLTrustTypePromptAndCache  // prompt the user on invalid certificates, and cache those they have allowed.
} RZWebServiceRequestSSLTrustType;

// Parameter mode
typedef enum {
    RZWebserviceRequestParameterModeDefault = 0,
    RZWebServiceRequestParameterModeURL,
    RZWebServiceRequestParameterModeBody
} RZWebServiceRequestParameterMode;

@interface RZWebServiceRequest : NSOperation <NSURLConnectionDataDelegate>
{
@private
    NSMutableDictionary* _headers;
}

-(id) initWithApiInfo:(NSDictionary*)apiInfo target:(id)target;
-(id) initWithApiInfo:(NSDictionary *)apiInfo target:(id)target parameters:(NSDictionary*)parameters;

- (id)initWithApiInfo:(NSDictionary*)apiInfo completion:(RZWebServiceRequestCompletionBlock)completionBlock;
- (id)initWithApiInfo:(NSDictionary*)apiInfo parameters:(NSDictionary*)parameters completion:(RZWebServiceRequestCompletionBlock)completionBlock;

- (id)initWithApiInfo:(NSDictionary*)apiInfo
           parameters:(NSDictionary*)parameters
     preProcessBlocks:(NSArray*)preProcessBlocks
    postProcessBlocks:(NSArray*)postProcessBlocks
           completion:(RZWebServiceRequestCompletionBlock)completionBlock;

// create a request
-(id) initWithURL:(NSURL*)url 
       httpMethod:(NSString*)httpMethod
        andTarget:(id)target 
  successCallback:(SEL)successCallback
  failureCallback:(SEL)failureCallback
expectedResultType:(NSString*)expectedResultType
         bodyType:(NSString*)bodyType
    andParameters:(NSDictionary*)parameters;

- (id) initWithURL:(NSURL *)url
        httpMethod:(NSString *)httpMethod
expectedResultType:(NSString *)expectedResultType
          bodyType:(NSString *)bodyType
        parameters:(NSDictionary *)parameters
        completion:(RZWebServiceRequestCompletionBlock)completionBlock;

- (id) initWithURL:(NSURL *)url
        httpMethod:(NSString *)httpMethod
  preProcessBlocks:(NSArray*)preProcessBlocks
 postProcessBlocks:(NSArray*)postProcessBlocks
expectedResultType:(NSString *)expectedResultType
          bodyType:(NSString *)bodyType
        parameters:(NSDictionary *)parameters
        completion:(RZWebServiceRequestCompletionBlock)completionBlock;

- (id)copyWithZone:(NSZone *)zone;

// add pre or post processing blocks
- (void)addPreProcessingBlock:(RZWebServiceRequestPreProcessBlock)block;
- (void)addPostProcessingBlock:(RZWebServiceRequestPostProcessBlock)block;

// set a request header on the outgoing request
-(void) setValue:(NSString*)value forHTTPHeaderField:(NSString*)headerField;

// Sets how we handle Authentication challenges with certain Certificate types
-(void) setSSLCertificateType:(RZWebServiceRequestSSLTrustType)sslCertificateType WithChallengeBlock:(RZWebServiceRequestSSLChallengeBlock)challengeBlock;

// add/remove progress observer for upload/download progress
- (void)addProgressObserver:(id<RZWebServiceRequestProgressObserver>)observer;
- (void)removeProgressObserver:(id<RZWebServiceRequestProgressObserver>)observer;
- (void)removeAllProgressObservers;

//! Parameter mode override
/*!
    If the mode is the default (RZWebserviceRequestParameterModeDefault), the HTTP method
    will determine whether the parameters are added to the URL or to the reqest body, based
    on HTTP standards (GET, PUT, DELETE go in the URL, POST goes in the body). Otherwise,
    the override is obeyed regardless of HTTP method.
*/
@property (assign, nonatomic) RZWebServiceRequestParameterMode parameterMode;

// the WebServiceManager that has queued this request.
@property (weak, nonatomic) RZWebServiceManager* manager;

@property (weak, nonatomic)   id target; // Deprecated - Use CompletionBlocks instead
@property (assign, nonatomic) SEL successHandler;   // Deprecated - Use CompletionBlocks instead
@property (assign, nonatomic) SEL failureHandler;   // Deprecated - Use CompletionBlocks instead
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

// This is the delimiter that will be used for parameters with an array of values
@property (strong, nonatomic) NSString* parameterArrayDelimiter;

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

// response info
@property (strong, readonly, nonatomic) NSDictionary* responseHeaders;
@property (assign, readonly, nonatomic) NSInteger statusCode;

// Set to NO to prevent caching URL response. Recommended for large file downloads. Default is YES
@property (assign, nonatomic) BOOL shouldCacheResponse;

@property (assign, nonatomic) BOOL ignoreCertificateValidity;

// Note: These pre/post process blocks are not used at the moment.
@property (copy, nonatomic) NSArray *preProcessBlocks;
@property (copy, nonatomic) NSArray *postProcessBlocks;

// Note: Completion Blocks take precidence over success/failure callbacks
@property (copy, nonatomic) RZWebServiceRequestCompletionBlock requestCompletionBlock;

@end


@protocol RZWebServiceRequestProgressObserver <NSObject>

- (void)webServiceRequest:(RZWebServiceRequest*)request setProgress:(float)progress;

@end


// Parameter Type Enum
typedef enum {
    RZWebServiceRequestParameterTypeQueryString,                                 // For String and Number parameters that can go in the query string of a URL
    RZWebServiceRequestParameterTypeFile,                                        // For File URL parameters in multi-part form posts
    RZWebServiceRequestParameterTypeBinaryData                                   // For images and other binary data parameters in multi-part form posts
} RZWebServiceRequestParameterType;




// Parameter object for WebService Requests
@interface RZWebServiceRequestParameter : NSObject

@property (strong, nonatomic)    NSString*                        parameterName;
@property (strong, nonatomic)    id                               parameterValue;
@property (assign, nonatomic)    RZWebServiceRequestParameterType parameterType;

+ (id)parameterWithName:(NSString*)name value:(id)value type:(RZWebServiceRequestParameterType)type;
- (id)initWithName:(NSString*)name value:(id)value type:(RZWebServiceRequestParameterType)type;
- (unsigned long long)contentLength;

@end

@interface NSDictionary (RZWebServiceRequestParameters)

- (NSMutableArray*)convertToURLEncodedParameters;

@end
