//
//  RZCacheSchema.h
//  WebServiceManager
//
//  Created by Alex Rouse on 7/13/12.
//  Copyright (c) 2012 Raizlabs Corporation. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RZCacheSchema : NSObject

- (NSURL *)cacheURLFromRemoteURL:(NSURL *)remoteURL;
- (NSURL *)cacheURLFromCustomName:(NSString *)name;

@property (strong, nonatomic) NSURL *downloadCacheDirectory;

@end
