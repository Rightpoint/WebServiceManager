//
//  RZFileCacheSchema.m
//  WebServiceManager
//
//  Created by Alex Rouse on 6/26/12.
//  Copyright (c) 2012 Raizlabs Corporation. All rights reserved.
//

#import "RZFileCacheSchema.h"

@interface RZFileCacheSchema ()
@property (strong, nonatomic) NSString *hashSecret;
@end

@implementation RZFileCacheSchema
@synthesize downloadCacheDirectory = _downloadCacheDirectory;
@synthesize hashSecret = _hashSecret;

- (id)init {
    self = [super init];
    if (self) {
        //self.hashSecret = @"rzfileschema";
    }
    return self;
}

- (NSURL *)cacheURLFromRemoteURL:(NSURL *)remoteURL {
    NSString* cacheName = (NSString*)[remoteURL absoluteString];
    NSString* fileFormat = [[(NSString *)[remoteURL.pathComponents lastObject] componentsSeparatedByString:@"."] lastObject];
    NSURL* cachePath = [[self downloadCacheDirectory] URLByAppendingPathComponent:[NSString stringWithFormat:@"%d.%@",[cacheName hash],fileFormat]];
    return cachePath;
}

- (NSURL *)cacheURLFromCustomName:(NSString *)name {
    
    NSURL* cacheURL = [[self downloadCacheDirectory] URLByAppendingPathComponent:[NSString stringWithFormat:@"%d",[name hash]]];
    return cacheURL;
}
@end
