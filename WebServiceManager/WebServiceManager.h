//
//  WebServiceManager.h
//  BloomingdalesNYC
//
//  Created by Craig Spitzkoff on 10/21/11.
//  Copyright (c) 2011 Raizlabs Corporation. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WebServiceRequest.h"

@interface WebServiceManager : NSObject <WebServiceRequestDelegate>

@property (strong, nonatomic) NSDictionary* apiCalls;

-(id) initWithCallsPath:(NSString*)callsPath;
-(id) initWithCalls:(NSDictionary*)apiCalls;

-(WebServiceRequest*) makeRequestWithKey:(NSString*)key andTarget:(id)target;

-(void) cancelRequestsForTarget:(id)target;

@end
