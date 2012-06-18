//
//  RZFileManager.m
//  WebServiceManager
//
//  Created by Joe Goullaud on 6/18/12.
//  Copyright (c) 2012 Raizlabs Corporation. All rights reserved.
//

#import "RZFileManager.h"
#import "RZWebServiceManager.h"
#import "RZWebServiceRequest.h"

@interface RZFileManager ()

@property (strong, nonatomic, readonly) NSMutableSet *downloadRequests;
@property (strong, nonatomic, readonly) NSMutableSet *uploadRequests;

- (NSURL*)defaultDownloadCacheURL;

- (RZWebServiceRequest*)requestWithDownloadURL:(NSURL*)downloadURL;
- (RZWebServiceRequest*)requestWithUploadURL:(NSURL*)uploadURL;

@end

@implementation RZFileManager
@synthesize downloadCacheDirectory = _downloadCacheDirectory;
@synthesize shouldCacheDownloads = _shouldCacheDownloads;

@synthesize downloadRequests = _downloadRequests;
@synthesize uploadRequests = _uploadRequests;

+ (RZFileManager*)defaultManager
{
    static RZFileManager* s_RZFileManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_RZFileManager = [[RZFileManager alloc] init];
    });
    
    return s_RZFileManager;
}

- (id)init
{
    if ((self = [super init]))
    {
        self.downloadCacheDirectory = [self defaultDownloadCacheURL];
        self.shouldCacheDownloads = YES;
    }
    
    return self;
}

- (RZWebServiceRequest*)downloadFileFromURL:(NSURL*)remoteURL withProgressDelegate:(id<RZFileProgressDelegate>)progressDelegate completion:(RZFileManagerDownloadCompletionBlock)completionBlock
{
    [self downloadFileFromURL:remoteURL withProgressDelegate:progressDelegate enqueue:YES completion:completionBlock];
}

- (RZWebServiceRequest*)downloadFileFromURL:(NSURL*)remoteURL withProgressDelegate:(id<RZFileProgressDelegate>)progressDelegate enqueue:(BOOL)enqueue completion:(RZFileManagerDownloadCompletionBlock)completionBlock
{
    
}

- (RZWebServiceRequest*)uploadFile:(NSURL*)localFile toURL:(NSURL*)remoteURL withProgressDelegate:(id<RZFileProgressDelegate>)progressDelegate completion:(RZFileManagerUploadCompletionBlock)completionBlock
{
    [self uploadFile:localFile toURL:remoteURL withProgressDelegate:progressDelegate enqueue:YES completion:completionBlock];
}

- (RZWebServiceRequest*)uploadFile:(NSURL*)localFile toURL:(NSURL*)remoteURL withProgressDelegate:(id<RZFileProgressDelegate>)progressDelegate enqueue:(BOOL)enqueue completion:(RZFileManagerUploadCompletionBlock)completionBlock
{
    
}

// Cancel File Transfer Requests
- (void)cancelDownloadFromURL:(NSURL*)remoteURL
{
    
}

- (void)cancelUploadToURL:(NSURL*)remoteURL
{
    
}

#pragma mark - Accessor Overrides

- (NSMutableSet*)downloadRequests
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _downloadRequests = [NSMutableSet set];
    });
    
    return _downloadRequests;
}

- (NSMutableSet*)uploadRequests
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _uploadRequests = [NSMutableSet set];
    });
    
    return _uploadRequests;
}

#pragma mark - Private Methods

- (NSURL*)defaultDownloadCacheURL
{
    NSArray* cachePathsArray = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString* cachePath = [cachePathsArray lastObject];
    
    NSURL *cacheURL = nil;
    
    if (cachePath)
    {
        cacheURL = [NSURL fileURLWithPath:[cachePath stringByAppendingPathComponent:@"DownloadCache"] isDirectory:YES];
    }
    
    return cacheURL;
}

- (RZWebServiceRequest*)requestWithDownloadURL:(NSURL*)downloadURL
{
    NSSet *filteredRequests = [self.downloadRequests filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"url == %@", downloadURL]];
    
    return [filteredRequests anyObject];
}

- (RZWebServiceRequest*)requestWithUploadURL:(NSURL*)uploadURL
{
    NSSet *filteredRequests = [self.uploadRequests filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"url == %@", uploadURL]];
    
    return [filteredRequests anyObject];
}

@end
