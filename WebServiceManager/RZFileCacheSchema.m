//
//  RZFileCacheSchema.m
//  WebServiceManager
//
//  Created by Alex Rouse on 6/26/12.
//  Copyright (c) 2012 Raizlabs Corporation. All rights reserved.
//

#import "RZFileCacheSchema.h"
#import "NSString+RZMD5.h"

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
    NSString* cacheName = [remoteURL absoluteString];
    NSString* fileFormat = [[(NSString *)[remoteURL.pathComponents lastObject] componentsSeparatedByString:@"."] lastObject];
    NSURL* cachePath = [[self downloadCacheDirectory] URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.%@", [cacheName digest], fileFormat]];
    return cachePath;
}

- (NSURL *)cacheURLFromCustomName:(NSString *)name {
    
    NSURL* cacheURL = [[self downloadCacheDirectory] URLByAppendingPathComponent:[NSString stringWithFormat:@"%@", [name digest]]];
    return cacheURL;
}
@end
