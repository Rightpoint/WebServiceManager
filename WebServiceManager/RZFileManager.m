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

- (RZWebServiceRequest*)downloadFileFromURL:(NSURL*)remoteURL withProgressDelegate:(id<RZFileProgressDelegate>)progressDelegate cacheName:(NSString *)name enqueue:(BOOL)enqueue completion:(RZFileManagerDownloadCompletionBlock)completionBlock 
{
    NSSet* progressDelegateSet = [[NSSet alloc] initWithObjects:progressDelegate, nil];
    return [self downloadFileFromURL:remoteURL withProgressDelegateSet:progressDelegateSet cacheName:name enqueue:enqueue completion:completionBlock];
}

- (RZWebServiceRequest*)downloadFileFromURL:(NSURL*)remoteURL withProgressDelegateSet:(NSSet *)progressDelegate enqueue:(BOOL)enqueue completion:(RZFileManagerDownloadCompletionBlock)completionBlock {
    return [self downloadFileFromURL:remoteURL withProgressDelegateSet:progressDelegate cacheName:nil enqueue:enqueue completion:completionBlock];
}

- (RZWebServiceRequest*)downloadFileFromURL:(NSURL*)remoteURL withProgressDelegateSet:(NSSet *)progressDelegate cacheName:(NSString *)name enqueue:(BOOL)enqueue completion:(RZFileManagerDownloadCompletionBlock)completionBlock
{
    NSString* cacheName = (NSString*)[remoteURL.pathComponents lastObject];
    if (name != nil) {
        NSString* fileFormat = [[(NSString *)[remoteURL.pathComponents lastObject] componentsSeparatedByString:@"."] lastObject];
        if ([name rangeOfString:[NSString stringWithFormat:@".%@",fileFormat]].location == NSNotFound) {
            cacheName = [NSString stringWithFormat:@"%@.%@",name,fileFormat];
        } else {
            cacheName = name;
        }
    }
    NSURL* cachePath = [[self downloadCacheDirectory] URLByAppendingPathComponent:cacheName];
    
    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:[cachePath path]];
    if (fileExists) {
        completionBlock(YES,cachePath,nil);
        return nil;
    }
    
    RZWebServiceRequest * request = [self.webManager makeRequestWithURL:remoteURL target:self successCallback:@selector(downloadRequestComplete:request:) failureCallback:@selector(downloadRequestFailed:request:) parameters:nil enqueue:NO];
    [self putObject:progressDelegate inRequest:request atKey:kProgressDelegateKey];
    [self putBlock:completionBlock inRequest:request atKey:kCompletionBlockKey];
    request.targetFileURL = cachePath;
    if (enqueue) {
        [self.webManager enqueueRequest:request];
    }
    [self.downloadRequests addObject:request];    
    return request;
}

- (RZWebServiceRequest*)uploadFile:(NSURL*)localFile toURL:(NSURL*)remoteURL withProgressDelegate:(id<RZFileProgressDelegate>)progressDelegate completion:(RZFileManagerUploadCompletionBlock)completionBlock
{
    return [self uploadFile:localFile toURL:remoteURL withProgressDelegateSet:[NSSet setWithObject:progressDelegate] enqueue:YES completion:completionBlock];
}

- (RZWebServiceRequest*)uploadFile:(NSURL*)localFile toURL:(NSURL*)remoteURL withProgressDelegate:(id<RZFileProgressDelegate>)progressDelegate enqueue:(BOOL)enqueue completion:(RZFileManagerUploadCompletionBlock)completionBlock
{
    return [self uploadFile:localFile toURL:remoteURL withProgressDelegateSet:[NSSet setWithObject:progressDelegate] enqueue:enqueue completion:completionBlock];
}

- (RZWebServiceRequest*)uploadFile:(NSURL*)localFile toURL:(NSURL*)remoteURL withProgressDelegateSet:(NSSet *)progressDelegates completion:(RZFileManagerUploadCompletionBlock)completionBlock
{
    return [self uploadFile:localFile toURL:remoteURL withProgressDelegateSet:progressDelegates enqueue:YES completion:completionBlock];
}

- (RZWebServiceRequest*)uploadFile:(NSURL*)localFile toURL:(NSURL*)remoteURL withProgressDelegateSet:(NSSet *)progressDelegates enqueue:(BOOL)enqueue completion:(RZFileManagerUploadCompletionBlock)completionBlock
{
    // Check if file exists
    
    // Check if it's a local file
    
    RZWebServiceRequest * request = [self.webManager makeRequestWithURL:remoteURL target:self successCallback:@selector(uploadRequestComplete:request:) failureCallback:@selector(uploadRequestFailed:request:) parameters:nil enqueue:NO];
    [self putObject:progressDelegates inRequest:request atKey:kProgressDelegateKey];
    [self putBlock:completionBlock inRequest:request atKey:kCompletionBlockKey];
    request.httpMethod = @"PUT";
    request.uploadFileURL = localFile;
    if (enqueue) {
        [self.webManager enqueueRequest:request];
    }
    [self.uploadRequests addObject:request];    
    return request;
}

- (void)removeProgressDelegate:(id<RZFileProgressDelegate>)delegate fromURL:(NSURL *)remoteURL 
{
    [self removeObject:delegate fromRequest:[self requestWithDownloadURL:remoteURL] atKey:kProgressDelegateKey];
}

- (void)removeAllProgressDelegatesFromURL:(NSURL *)remoteURL
{
    [self removeKey:kProgressDelegateKey fromRequest:[self requestWithDownloadURL:remoteURL]];
}

- (void)addProgressDelegate:(id<RZFileProgressDelegate>)delegate toURL:(NSURL *)remoteURL 
{
    [self addObject:delegate toRequest:[self requestWithDownloadURL:remoteURL] atKey:kProgressDelegateKey];
}

// Cancel File Transfer Requests
- (void)cancelDownloadFromURL:(NSURL*)remoteURL
{
    [[self requestWithDownloadURL:remoteURL] cancel];
}

- (void)cancelUploadToURL:(NSURL*)remoteURL
{
    [[self requestWithUploadURL:remoteURL] cancel];
}



- (void)deleteFileFromCacheWithName:(NSString *)name ofType:(NSString *)extension 
{
    [self deleteFileFromCacheWithName:[name stringByAppendingPathExtension:extension]];
}

- (void)deleteFileFromCacheWithName:(NSString *)name 
{
    NSURL* filePath = [[self downloadCacheDirectory] URLByAppendingPathComponent:name];
    [self deleteFileFromCacheWithURL:filePath];
}

- (void)deleteFileFromCacheWithURL:(NSURL *)remoteURL 
{
    NSURL* filePath = [[self downloadCacheDirectory] URLByAppendingPathComponent:(NSString*)[remoteURL.pathComponents lastObject]];

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
    RZFileManagerDownloadCompletionBlock compBlock = [request.userInfo objectForKey:kCompletionBlockKey];
    [[self downloadRequests] removeObject:request];
    compBlock(YES,request.targetFileURL,request);
}
- (void)downloadRequestFailed:(NSError *)error request:(RZWebServiceRequest *)request {
    RZFileManagerDownloadCompletionBlock compBlock = [request.userInfo objectForKey:kCompletionBlockKey];
    [[self downloadRequests] removeObject:request];
    compBlock(NO,request.targetFileURL,request);
}

#pragma mark - Upload Completion Methods

- (void)uploadRequestComplete:(NSData *)data request:(RZWebServiceRequest *)request {
    RZFileManagerUploadCompletionBlock compBlock = [request.userInfo objectForKey:kCompletionBlockKey];
    [self.uploadRequests removeObject:request];
    compBlock(YES,request.uploadFileURL,request);
}
- (void)uploadRequestFailed:(NSError *)error request:(RZWebServiceRequest *)request {
    RZFileManagerUploadCompletionBlock compBlock = [request.userInfo objectForKey:kCompletionBlockKey];
    [self.uploadRequests removeObject:request];
    compBlock(NO,request.uploadFileURL,request);
}

#pragma mark - Progress Delegate Helper Methods

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
    NSArray* cachePathsArray = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
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
        cacheURL = [NSURL fileURLWithPath:fullPath];
    }
    
    return cacheURL;
}
- (NSURL *)defaultDocumentsDirectoryURL {
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
            if (error != nil) {
                NSLog(@"Error:%@:",error);
            }
        }
        cacheURL = [NSURL fileURLWithPath:fullPath];
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

#pragma mark - Request Modification Helper functions

- (void)putBlock:(id)block inRequest:(RZWebServiceRequest*)request atKey:(id)key
{
    [self putObject:[block copy] inRequest:request atKey:key];
    
}

- (void)putObject:(id)obj inRequest:(RZWebServiceRequest*)request atKey:(id)key
{
    if(nil != obj && nil != key)
    {
        NSMutableDictionary* requestDictionary = nil;
        if (nil != request.userInfo) {
            requestDictionary = [NSMutableDictionary dictionaryWithDictionary:request.userInfo];
        }
        
        if(!requestDictionary) {
            requestDictionary = [[NSMutableDictionary alloc] initWithCapacity:1];
        }
        
        [requestDictionary setObject:obj forKey:key];
        request.userInfo = requestDictionary;
    }
}

- (void)addObject:(id)obj toRequest:(RZWebServiceRequest *)request atKey:(id)key
{
    if(nil != obj && nil != key)
    {
        NSMutableDictionary* requestDictionary = nil;
        if (nil != request.userInfo) {
            requestDictionary = [NSMutableDictionary dictionaryWithDictionary:request.userInfo];
        }
        
        if(!requestDictionary) {
            requestDictionary = [[NSMutableDictionary alloc] initWithCapacity:1];
        }
        
        NSMutableSet* userInfoSet = nil;
        if (nil != [requestDictionary objectForKey:key]) {
            userInfoSet = [NSMutableSet setWithSet:[requestDictionary objectForKey:key]];
        }
        
        if (!userInfoSet) {
            userInfoSet = [[NSMutableSet alloc] initWithCapacity:1];
        }
        
        [userInfoSet addObject:obj];
        
        [requestDictionary setObject:userInfoSet forKey:key];

        request.userInfo = requestDictionary;
    }

}

- (void)removeObject:(id)obj fromRequest:(RZWebServiceRequest*)request atKey:(id)key
{
    if(nil != obj && nil != key)
    {
        NSMutableDictionary* requestDictionary = nil;
        if (nil != request.userInfo) {
            requestDictionary = [NSMutableDictionary dictionaryWithDictionary:request.userInfo];
        }
        
        if(!requestDictionary) {
            return;
        }
        
        NSMutableSet * userInfoSet = [NSMutableSet setWithSet:(NSSet *)[requestDictionary objectForKey:key]];
        [userInfoSet removeObject:obj];
        [requestDictionary setObject:userInfoSet forKey:key];
        request.userInfo = requestDictionary;
    }
}
- (void)removeKey:(id)key fromRequest:(RZWebServiceRequest*)request
{
    if(nil != key)
    {
        NSMutableDictionary* requestDictionary = nil;
        if (nil != request.userInfo) {
            requestDictionary = [NSMutableDictionary dictionaryWithDictionary:request.userInfo];
        }
        
        if(!requestDictionary) {
            return;
        }
        
        [requestDictionary removeObjectForKey:key];
        request.userInfo = requestDictionary;
    }
}

@end
