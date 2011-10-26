//
//  NSURL+WebService_NSURL.h
//  WebServiceManager
//
//  Created by Craig Spitzkoff on 10/25/11.
//  Copyright (c) 2011 Raizlabs Corporation. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSURL (WebService_NSURL)

- (NSURL *)URLByAddingParameters:(NSDictionary *)parameters;

@end
