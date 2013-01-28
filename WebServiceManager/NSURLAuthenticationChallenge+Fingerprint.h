//
//  NSURLAuthenticationChallenge+Fingerprint.h
//  WebServiceManager
//
//  Created by Craig Spitzkoff on 1/28/13.
//  Copyright (c) 2013 Raizlabs Corporation. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSURLAuthenticationChallenge (Fingerprint)

-(NSString*) sha1Fingerprint;

@end
