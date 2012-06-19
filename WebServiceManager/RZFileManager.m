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


NSString * const kCompletionBlockKey = @"completionBlockKey";
NSString * const kProgressDelegateKey = @"progressDelegateKey";

@implementation RZFileManager
@synthesize downloadCacheDirectory = _downloadCacheDirectory;
@synthesize shouldCacheDownloads = _shouldCacheDownloads;
@synthesize webManager = _webManager;

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
    return [self downloadFileFromURL:remoteURL withProgressDelegate:progressDelegate enqueue:YES completion:completionBlock];
}

- (RZWebServiceRequest*)downloadFileFromURL:(NSURL*)remoteURL withProgressDelegate:(id<RZFileProgressDelegate>)progressDelegate enqueue:(BOOL)enqueue completion:(RZFileManagerDownloadCompletionBlock)completionBlock
{
    NSSet* progressDelegateSet = [[NSSet alloc] initWithObjects:progressDelegate, nil];
    return [self downloadFileFromURL:remoteURL withProgressDelegateSet:progressDelegateSet enqueue:enqueue completion:completionBlock];
}

- (RZWebServiceRequest*)downloadFileFromURL:(NSURL*)remoteURL withProgressDelegateSet:(NSSet *)progressDelegate enqueue:(BOOL)enqueue completion:(RZFileManagerDownloadCompletionBlock)completionBlock {
    
    [self deleteFileFromCacheWithURL:remoteURL];
    NSURL* filePath = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@",[self defaultDownloadCacheURL],(NSString*)[remoteURL.pathComponents lastObject]]];
    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:[filePath path]];
    if (fileExists) {
        completionBlock(YES,filePath,nil);
        return nil;
    }
    RZWebServiceRequest * request = [self.webManager makeRequestWithURL:remoteURL target:self successCallback:@selector(downloadRequestComplete:request:) failureCallback:@selector(downloadRequestFailed:request:) parameters:nil enqueue:NO];
    [self putObject:progressDelegate inRequest:request atKey:kProgressDelegateKey];
    [self putObject:completionBlock inRequest:request atKey:kCompletionBlockKey];
    request.targetFileURL = filePath;
    if (enqueue) {
        [self.webManager enqueueRequest:request];
    }
    return request;

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

- (void)deleteFileFromCacheWithURL:(NSURL *)remoteURL 
{
    NSURL* filePath = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@",[self defaultDownloadCacheURL],(NSString*)[remoteURL.pathComponents lastObject]]];
    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:[filePath path]];
    if (fileExists) {
        NSError* error = nil;
        [[NSFileManager defaultManager] removeItemAtPath:[filePath path] error:&error];
        if (error != nil) {
            NSLog(@"Error removing file:%@ with error:%@",remoteURL, error);
        }
    }

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

#pragma mark - Download Completion Methods

- (void)downloadRequestComplete:(NSData *)data request:(RZWebServiceRequest *)request {
    NSLog(@"\n\nRequest:%@\n TargetFile:%@\n ",request.url, request.targetFileURL);
    RZFileManagerDownloadCompletionBlock compBlock = [request.userInfo objectForKey:kCompletionBlockKey];
    compBlock(YES,request.targetFileURL,request);
}
- (void)downloadRequestFailed:(NSError *)error request:(RZWebServiceRequest *)request {
    NSLog(@"RequestFAILED:%@\n WithError:%@",request.url, error);
    RZFileManagerDownloadCompletionBlock compBlock = [request.userInfo objectForKey:kCompletionBlockKey];
    compBlock(NO,request.targetFileURL,request);
}

- (void)setProgress:(float)progress withRequest:(RZWebServiceRequest *)request {
    id delegateSet = [request.userInfo objectForKey:kProgressDelegateKey];
    if ([delegateSet isKindOfClass:[NSSet class]]) {
        NSSet* delegates = (NSSet *)delegateSet;
        [delegates enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
            id<RZFileProgressDelegate> delegate = (id<RZFileProgressDelegate>)obj;
            [delegate setProgress:progress];
        }];
    }
}

#pragma mark - Private Methods

- (NSURL*)defaultDownloadCacheURL
{
    NSArray* cachePathsArray = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString* cachePath = [cachePathsArray lastObject];
    
    NSURL *cacheURL = nil;
    
    if (cachePath)
    {
        NSError* error = nil;
        cacheURL = [NSURL fileURLWithPath:cachePath isDirectory:YES];
        NSString* fullPath = [cachePath stringByAppendingPathComponent:@"DownloadCache"];
        if (![[NSFileManager defaultManager] fileExistsAtPath:fullPath])
        {
            [[NSFileManager defaultManager] createDirectoryAtPath:fullPath
                                      withIntermediateDirectories:NO
                                                       attributes:nil
                                                            error:&error];
            if (error != nil)
                NSLog(@"Error:%@:",error);
        }
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

- (void)putObject:(id)obj inRequest:(RZWebServiceRequest*)request atKey:(id)key
{
    if(nil != obj && nil != key)
    {
        NSMutableDictionary* requestDictionary = nil;
        if (nil != request.userInfo) {
            requestDictionary = [NSMutableDictionary dictionaryWithDictionary:request.userInfo];
        }
        
        if(!requestDictionary)
            requestDictionary = [[NSMutableDictionary alloc] initWithCapacity:1];
        
        [requestDictionary setObject:obj forKey:key];
        request.userInfo = requestDictionary;
    }
}

@end
