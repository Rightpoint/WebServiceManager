//
//  WebServiceRequest.h
//  BloomingdalesNYC
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


@protocol WebServiceRequestDelegate;
@class WebServiceManager;

@interface WebServiceRequest : NSObject <NSURLConnectionDelegate>

-(id) initWithApiInfo:(NSDictionary*)apiInfo target:(id)target;
-(void) start;
-(void) cancel;

@property (unsafe_unretained, nonatomic) id target;
@property (strong, nonatomic) NSDictionary* apiInfo;
@property (strong, nonatomic) NSURL* url;
@property (unsafe_unretained, nonatomic) id<WebServiceRequestDelegate> delegate;

@end


@protocol WebServiceRequestDelegate <NSObject>

-(void) webServiceRequest:(WebServiceRequest*)request failedWithError:(NSError*)error;
-(void) webServiceRequest:(WebServiceRequest *)request completedWithData:(NSData*)data;

@end