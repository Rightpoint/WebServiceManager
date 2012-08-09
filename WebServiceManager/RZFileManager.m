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
#import "RZFileCacheSchema.h"

@interface RZFileManager ()

@property (strong, nonatomic, readonly) NSMutableSet *downloadRequests;
@property (strong, nonatomic, readonly) NSMutableSet *uploadRequests;

- (NSSet*)requestsWithDownloadURL:(NSURL*)downloadURL;
- (NSSet*)requestsWithUploadURL:(NSURL*)uploadURL;
- (NSSet*)requestsWithUploadFileURL:(NSURL*)uploadFileURL;

- (void)addProgressDelegate:(id<RZFileProgressDelegate>)delegate toRequests:(NSSet*)requests;
- (void)removeProgressDelegate:(id<RZFileProgressDelegate>)delegate fromRequests:(NSSet*)requests;
- (void)removeAllProgressDelegatesFromRequests:(NSSet*)requests;

@end


NSString* const kCompletionBlockKey = @"completionBlockKey";
NSString* const kProgressDelegateKey = @"progressDelegateKey";

NSString* const RZFileManagerNotificationRemoteURLKey = @"RZFileManagerNotificationRemoteURLKey";
NSString* const RZFileManagerNotificationLocalURLKey = @"RZFileManagerNotificationLocalURLKey";
NSString* const RZFileManagerNotificationRequestSuccessfulKey = @"RZFileManagerNotificationRequestSuccessfulKey";

NSString* const RZFileManagerFileDownloadStartedNotification = @"RZFileManagerFileDownloadStartedNotification ";
NSString* const RZFileManagerFileDownloadCompletedNotification = @"RZFileManagerFileDownloadCompletedNotification";
NSString* const RZFileManagerFileUploadStartedNotification = @"RZFileManagerFileUploadStartedNotification";
NSString* const RZFileManagerFileUploadCompletedNotification = @"RZFileManagerFileUploadCompletedNotification";

@implementation RZFileManager
@synthesize shouldCacheDownloads = _shouldCacheDownloads;
@synthesize webManager = _webManager;
@synthesize cacheSchema = _cacheSchema;

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


+ (NSURL*)defaultDownloadCacheURL
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

+ (NSURL *)defaultDocumentsDirectoryURL {
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


- (id)init
{
    if ((self = [super init]))
    {
        self.shouldCacheDownloads = YES;
    }
    
    return self;
}

#pragma mark - Download File Request Methods

- (RZWebServiceRequest*)downloadFileFromURL:(NSURL*)remoteURL withProgressDelegate:(id<RZFileProgressDelegate>)progressDelegate completion:(RZFileManagerDownloadCompletionBlock)completionBlock
{
    return [self downloadFileFromURL:remoteURL withProgressDelegate:progressDelegate enqueue:YES completion:completionBlock];
}

- (RZWebServiceRequest*)downloadFileFromURL:(NSURL*)remoteURL withProgressDelegate:(id<RZFileProgressDelegate>)progressDelegate enqueue:(BOOL)enqueue completion:(RZFileManagerDownloadCompletionBlock)completionBlock
{
    NSSet* progressDelegateSet = [[NSSet alloc] initWithObjects:progressDelegate, nil];
    return [self downloadFileFromURL:remoteURL withProgressDelegateSet:progressDelegateSet enqueue:enqueue completion:completionBlock];
}

- (RZWebServiceRequest*)downloadFileFromURL:(NSURL*)remoteURL withProgressDelegateSet:(NSSet *)progressDelegate enqueue:(BOOL)enqueue completion:(RZFileManagerDownloadCompletionBlock)completionBlock
{
    NSURL* cacheURL = nil;
    cacheURL = [self.cacheSchema cacheURLFromRemoteURL:remoteURL];
    
    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:[cacheURL path]];
    if (fileExists) {
        completionBlock(YES,cacheURL,nil);
        return nil;
    }
    
    RZWebServiceRequest * request = [self.webManager makeRequestWithURL:remoteURL target:self successCallback:@selector(downloadRequestComplete:request:) failureCallback:@selector(downloadRequestFailed:request:) parameters:nil enqueue:NO];
    [self putObject:progressDelegate inRequest:request atKey:kProgressDelegateKey];
    [self putBlock:completionBlock inRequest:request atKey:kCompletionBlockKey];
    request.targetFileURL = cacheURL;
    if (enqueue) {
        [self.webManager enqueueRequest:request];
    }
    [self.downloadRequests addObject:request]; 
    
    [self postDownloadStartedNotificationForRequest:request];
    
    return request;
}

#pragma mark - Upload File Request Methods

- (RZWebServiceRequest*)uploadFile:(NSURL*)localFile toURL:(NSURL*)remoteURL withProgressDelegate:(id<RZFileProgressDelegate>)progressDelegate completion:(RZFileManagerUploadCompletionBlock)completionBlock
{
    return [self uploadFile:localFile toURL:remoteURL withProgressDelegateSet:[NSSet setWithObjects:progressDelegate,nil] enqueue:YES completion:completionBlock];
}

- (RZWebServiceRequest*)uploadFile:(NSURL*)localFile toURL:(NSURL*)remoteURL withProgressDelegate:(id<RZFileProgressDelegate>)progressDelegate enqueue:(BOOL)enqueue completion:(RZFileManagerUploadCompletionBlock)completionBlock
{
    return [self uploadFile:localFile toURL:remoteURL withProgressDelegateSet:[NSSet setWithObjects:progressDelegate, nil] enqueue:enqueue completion:completionBlock];
}

- (RZWebServiceRequest*)uploadFile:(NSURL*)localFile toURL:(NSURL*)remoteURL withProgressDelegateSet:(NSSet *)progressDelegates completion:(RZFileManagerUploadCompletionBlock)completionBlock
{
    return [self uploadFile:localFile toURL:remoteURL withProgressDelegateSet:progressDelegates enqueue:YES completion:completionBlock];
}

- (RZWebServiceRequest*)uploadFile:(NSURL*)localFile toURL:(NSURL*)remoteURL withProgressDelegateSet:(NSSet *)progressDelegates enqueue:(BOOL)enqueue completion:(RZFileManagerUploadCompletionBlock)completionBlock
{
    // Check if it's a local file
    if (![localFile isFileURL])
    {
        NSLog(@"Upload File URL is not a file URL: %@", localFile);
        return nil;
    }
    
    // Check if file exists
    BOOL isDir = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:[localFile path] isDirectory:&isDir])
    {
        NSLog(@"Upload File does not exist: %@", [localFile path]);
        return nil;
    }
    
    // Check that the file is not a directory
    if (isDir)
    {
        NSLog(@"Upload File is a directory or symbolic link: %@", [localFile path]);
        return nil;
    }
    
    RZWebServiceRequest * request = [self.webManager makeRequestWithURL:remoteURL target:self successCallback:@selector(uploadRequestComplete:request:) failureCallback:@selector(uploadRequestFailed:request:) parameters:nil enqueue:NO];
    [self putObject:progressDelegates inRequest:request atKey:kProgressDelegateKey];
    [self putBlock:completionBlock inRequest:request atKey:kCompletionBlockKey];
    request.httpMethod = @"PUT";
    request.uploadFileURL = localFile;
    if (enqueue) {
        [self.webManager enqueueRequest:request];
    }
    [self.uploadRequests addObject:request];    
    
    [self postUploadStartedNotificationForRequest:request];
    
    return request;
}

#pragma mark - Download Progress Delegate Methods

- (void)addProgressDelegate:(id<RZFileProgressDelegate>)delegate toURL:(NSURL *)remoteURL 
{
    NSSet *requestsForURL = [self requestsWithDownloadURL:remoteURL];
    [self addProgressDelegate:delegate toRequests:requestsForURL];
}

- (void)removeProgressDelegate:(id<RZFileProgressDelegate>)delegate fromURL:(NSURL *)remoteURL 
{
    NSSet *requestsForURL = [self requestsWithDownloadURL:remoteURL];
    [self removeProgressDelegate:delegate fromRequests:requestsForURL];
}

- (void)removeAllProgressDelegatesFromURL:(NSURL *)remoteURL
{
    NSSet *requestsForURL = [self requestsWithDownloadURL:remoteURL];
    [self removeAllProgressDelegatesFromRequests:requestsForURL];
}

#pragma mark - Upload Progress Delegate Methods

- (void)addUploadProgressDelegate:(id<RZFileProgressDelegate>)delegate toURL:(NSURL*)remoteURL
{
    NSSet *requestsForURL = [self requestsWithUploadURL:remoteURL];
    [self addProgressDelegate:delegate toRequests:requestsForURL];
}

- (void)addUploadProgressDelegate:(id<RZFileProgressDelegate>)delegate toFileURL:(NSURL*)localFileURL
{
    NSSet *requestsForURL = [self requestsWithUploadFileURL:localFileURL];
    [self addProgressDelegate:delegate toRequests:requestsForURL];
}

- (void)removeUploadProgressDelegate:(id<RZFileProgressDelegate>)delegate fromURL:(NSURL*)remoteURL
{
    NSSet *requestsForURL = [self requestsWithUploadURL:remoteURL];
    [self removeProgressDelegate:delegate fromRequests:requestsForURL];
}

- (void)removeUplaodProgressDelegate:(id<RZFileProgressDelegate>)delegate fromFileURL:(NSURL*)localFileURL
{
    NSSet *requestsForURL = [self requestsWithUploadFileURL:localFileURL];
    [self removeProgressDelegate:delegate fromRequests:requestsForURL];
}

- (void)removeAllUploadProgressDelegatesFromURL:(NSURL*)remoteURL
{
    NSSet *requestsForURL = [self requestsWithUploadURL:remoteURL];
    [self removeAllProgressDelegatesFromRequests:requestsForURL];
}

- (void)removeAllUploadProgressDelegatesFromFileURL:(NSURL*)localFileURL
{
    NSSet *requestsForURL = [self requestsWithUploadFileURL:localFileURL];
    [self removeAllProgressDelegatesFromRequests:requestsForURL];
}

#pragma mark - Progress Delegate Remove All Methods

- (void)removeProgressDelegateFromAllDownloads:(id<RZFileProgressDelegate>)delegate
{
    [self removeProgressDelegate:delegate fromRequests:self.downloadRequests];
}

- (void)removeProgressDelegateFromAllUploads:(id<RZFileProgressDelegate>)delegate
{
    [self removeProgressDelegate:delegate fromRequests:self.uploadRequests];
}

- (void)removeProgressDelegateFromAllFileRequests:(id<RZFileProgressDelegate>)delegate
{
    [self removeProgressDelegate:delegate fromRequests:[self.downloadRequests setByAddingObjectsFromSet:self.uploadRequests]];
}

#pragma mark - Cancel File Transfer Requests Methods

- (void)cancelDownloadFromURL:(NSURL*)remoteURL
{
    NSSet *requestsForURL = [self requestsWithDownloadURL:remoteURL];
    
    [requestsForURL enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
        RZWebServiceRequest *request = (RZWebServiceRequest*)obj;
        [request cancel];
        [self postDownloadCompletedNotificationForRequest:request successful:NO];
    }];
    
    [self.downloadRequests minusSet:requestsForURL];
}

- (void)cancelUploadToURL:(NSURL*)remoteURL
{
    NSSet *requestsForURL = [self requestsWithUploadURL:remoteURL];
    
    [requestsForURL enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
        RZWebServiceRequest *request = (RZWebServiceRequest*)obj;
        [request cancel];
        [self postUploadCompletedNotificationForRequest:request successful:NO];
    }];

    [self.uploadRequests minusSet:requestsForURL];
}

- (void)cancelUploadOfLocalFileURL:(NSURL*)localFileURL
{
    NSSet *requestsForURL = [self requestsWithUploadFileURL:localFileURL];
    
    [requestsForURL enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
        RZWebServiceRequest *request = (RZWebServiceRequest*)obj;
        [request cancel];
        [self postUploadCompletedNotificationForRequest:request successful:NO];
    }];
    
    [self.uploadRequests minusSet:requestsForURL];
}

#pragma mark - Cache File Deletion Methods

- (void)deleteFileFromCacheWithName:(NSString *)name 
{
    NSURL* filePath = [self.cacheSchema.downloadCacheDirectory URLByAppendingPathComponent:name];
    [self deleteFileFromCacheWithURL:filePath];
}

- (void)deleteFileFromCacheWithRemoteURL:(NSURL *)remoteURL
{ 
    NSURL* cacheURL = [self.cacheSchema cacheURLFromRemoteURL:remoteURL];
    [self deleteFileFromCacheWithURL:cacheURL];
}

- (void)deleteFileFromCacheWithURL:(NSURL *)localURL 
{
    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:[localURL path]];
    if (fileExists) {
        NSError* error = nil;
        [[NSFileManager defaultManager] removeItemAtPath:[localURL path] error:&error];
        if (error != nil) {
            NSLog(@"Error removing file:%@ with error:%@",localURL, error);
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

- (RZCacheSchema *)cacheSchema 
{    
    if (_cacheSchema == nil) {
        _cacheSchema = [[RZFileCacheSchema alloc] init];
        _cacheSchema.downloadCacheDirectory = [RZFileManager defaultDownloadCacheURL];
    }
    
    return _cacheSchema;
}

#pragma mark - Download Completion Methods

- (void)downloadRequestComplete:(NSData *)data request:(RZWebServiceRequest *)request {
    RZFileManagerDownloadCompletionBlock compBlock = [request.userInfo objectForKey:kCompletionBlockKey];
    [[self downloadRequests] removeObject:request];
    compBlock(YES,request.targetFileURL,request);
    
    [self postDownloadCompletedNotificationForRequest:request successful:YES];
}
- (void)downloadRequestFailed:(NSError *)error request:(RZWebServiceRequest *)request {
    RZFileManagerDownloadCompletionBlock compBlock = [request.userInfo objectForKey:kCompletionBlockKey];
    [[self downloadRequests] removeObject:request];
    compBlock(NO,request.targetFileURL,request);

    [self postDownloadCompletedNotificationForRequest:request successful:NO];
}

#pragma mark - Upload Completion Methods

- (void)uploadRequestComplete:(NSData *)data request:(RZWebServiceRequest *)request {
    RZFileManagerUploadCompletionBlock compBlock = [request.userInfo objectForKey:kCompletionBlockKey];
    [self.uploadRequests removeObject:request];
    compBlock(YES,request.uploadFileURL,request);
    
    [self postUploadCompletedNotificationForRequest:request successful:YES];
}
- (void)uploadRequestFailed:(NSError *)error request:(RZWebServiceRequest *)request {
    RZFileManagerUploadCompletionBlock compBlock = [request.userInfo objectForKey:kCompletionBlockKey];
    [self.uploadRequests removeObject:request];
    compBlock(NO,request.uploadFileURL,request);
    
    [self postUploadCompletedNotificationForRequest:request successful:NO];
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



#pragma mark - Filtered Request Set Methods

- (NSSet*)requestsWithDownloadURL:(NSURL*)downloadURL
{
    NSSet *filteredRequests = [self.downloadRequests filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"url == %@", downloadURL]];
    
    return filteredRequests;
}

- (NSSet*)requestsWithUploadURL:(NSURL*)uploadURL
{
    NSSet *filteredRequests = [self.uploadRequests filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"url == %@", uploadURL]];
    
    return filteredRequests;
}

- (NSSet*)requestsWithUploadFileURL:(NSURL*)uploadFileURL
{
    NSSet *filteredRequests = [self.uploadRequests filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"uploadFileURL == %@", uploadFileURL]];
    
    return filteredRequests;
}

#pragma mark - Progress Delegate Mutator Helper Methods

- (void)addProgressDelegate:(id<RZFileProgressDelegate>)delegate toRequests:(NSSet*)requests
{
    [requests enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
        [self addObject:delegate toRequest:obj atKey:kProgressDelegateKey];
    }];
}

- (void)removeProgressDelegate:(id<RZFileProgressDelegate>)delegate fromRequests:(NSSet*)requests
{
    [requests enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
        [self removeObject:delegate fromRequest:obj atKey:kProgressDelegateKey];
    }];
}

- (void)removeAllProgressDelegatesFromRequests:(NSSet*)requests
{
    [requests enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
        [self removeKey:kProgressDelegateKey fromRequest:obj];
    }];
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

- (void)postDownloadStartedNotificationForRequest:(RZWebServiceRequest*)request{
    NSDictionary* notificationInfo = [NSDictionary dictionaryWithObject:request.url forKey:RZFileManagerNotificationRemoteURLKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:RZFileManagerFileDownloadStartedNotification object:self userInfo:notificationInfo];
}
- (void)postUploadStartedNotificationForRequest:(RZWebServiceRequest*)request{
    NSDictionary* notificationInfo = [NSDictionary dictionaryWithObject:request.url forKey:RZFileManagerNotificationRemoteURLKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:RZFileManagerFileUploadStartedNotification object:self userInfo:notificationInfo];
}
- (void)postDownloadCompletedNotificationForRequest:(RZWebServiceRequest*)request successful:(BOOL)success{
    NSDictionary* notificationInfo = 
    [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:request.url, request.targetFileURL,[NSNumber numberWithBool:success],nil]  
                                forKeys:[NSArray arrayWithObjects:RZFileManagerNotificationRemoteURLKey, RZFileManagerNotificationLocalURLKey, RZFileManagerNotificationRequestSuccessfulKey, nil]];
    [[NSNotificationCenter defaultCenter] postNotificationName:RZFileManagerFileDownloadCompletedNotification object:self userInfo:notificationInfo];

}
- (void)postUploadCompletedNotificationForRequest:(RZWebServiceRequest*)request successful:(BOOL)success{
   NSDictionary* notificationInfo = 
   [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:request.url, request.uploadFileURL,[NSNumber numberWithBool:success],nil]  
                               forKeys:[NSArray arrayWithObjects:RZFileManagerNotificationRemoteURLKey, RZFileManagerNotificationLocalURLKey, RZFileManagerNotificationRequestSuccessfulKey, nil]];
   [[NSNotificationCenter defaultCenter] postNotificationName:RZFileManagerFileUploadCompletedNotification object:self userInfo:notificationInfo];

}

@end
