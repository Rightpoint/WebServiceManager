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

#ifdef DEBUG
#define RZFileManagerLog(fmt, ...) NSLog((@"[RZFileManager] : " fmt), ##__VA_ARGS__)
#else
#define RZFileManagerLog(...)
#endif

@interface RZFileManager () <RZWebServiceRequestProgressObserver>

@property (strong, nonatomic, readonly) NSMutableSet *downloadRequests;
@property (strong, nonatomic, readonly) NSMutableSet *uploadRequests;

- (NSSet*)requestsWithDownloadURL:(NSURL*)downloadURL;
- (NSSet*)requestsWithUploadURL:(NSURL*)uploadURL;
- (NSSet*)requestsWithUploadFileURL:(NSURL*)uploadFileURL;

- (RZWebServiceRequest *)fileDownloadRequestWithProgressDelegates:(NSSet *)progressDelegates
                                                        remoteURL:(NSURL *)remoteURL
                                                         cacheURL:(NSURL *)cacheURL
                                                  completionBlock:(RZFileManagerDownloadCompletionBlock)completionBlock;

- (void)addProgressDelegate:(id<RZFileProgressDelegate>)delegate toRequests:(NSSet*)requests;
- (void)removeProgressDelegate:(id<RZFileProgressDelegate>)delegate fromRequests:(NSSet*)requests;
- (void)removeAllProgressDelegatesFromRequests:(NSSet*)requests;

// user info helpers
- (void)putBlock:(id)block inRequest:(RZWebServiceRequest*)request atKey:(id)key;
- (void)addBlock:(id)block toRequest:(RZWebServiceRequest*)request atKey:(id)key;
- (void)removeBlock:(id)block fromRequest:(RZWebServiceRequest*)request atKey:(id)key;
- (void)putObject:(id)obj inRequest:(RZWebServiceRequest*)request atKey:(id)key;
- (void)addObject:(id)obj toRequest:(RZWebServiceRequest *)request atKey:(id)key;
- (void)removeObject:(id)obj fromRequest:(RZWebServiceRequest*)request atKey:(id)key;
- (void)removeKey:(id)key fromRequest:(RZWebServiceRequest*)request;

// notification helpers
- (void)postDownloadStartedNotificationForRequest:(RZWebServiceRequest*)request;
- (void)postUploadStartedNotificationForRequest:(RZWebServiceRequest*)request;
- (void)postDownloadCompletedNotificationForRequest:(RZWebServiceRequest*)request successful:(BOOL)success;
- (void)postUploadCompletedNotificationForRequest:(RZWebServiceRequest*)request successful:(BOOL)success;

@end

NSString* const RZFileManagerDefaultServerTimeFormat = @"EEE, d MMM yyyy HH:mm:ss zzz";

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

// Need to synthesize these because they are readonly, lazy loaded
@synthesize downloadRequests = _downloadRequests;
@synthesize uploadRequests = _uploadRequests;

+ (instancetype)defaultManager
{
    static RZFileManager * s_defaultManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_defaultManager = [[self alloc] init];
    });
    
    return s_defaultManager;
}


+ (NSURL*)defaultDownloadCacheURL
{
    NSArray* cachePathsArray = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString* cachePath = [cachePathsArray lastObject];
    
    NSURL *cacheURL = nil;
    
    if (cachePath)
    {
        NSError* error = nil;
        NSString* fullPath = [cachePath stringByAppendingPathComponent:@"DownloadCache"];
        if (![[NSFileManager defaultManager] fileExistsAtPath:fullPath])
        {
            [[NSFileManager defaultManager] createDirectoryAtPath:fullPath
                                      withIntermediateDirectories:YES
                                                       attributes:nil
                                                            error:&error];
            if (error != nil)
                RZFileManagerLog(@"Error:%@:",error);
        }
        cacheURL = [NSURL fileURLWithPath:fullPath];
    }
    
    return cacheURL;
}

+ (NSURL *)defaultDocumentsDirectoryURL
{
    NSArray* cachePathsArray = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString* cachePath = [cachePathsArray lastObject];
    
    NSURL *cacheURL = nil;
    
    if (cachePath)
    {
        NSError* error = nil;
        NSString* fullPath = [cachePath stringByAppendingPathComponent:@"DownloadCache"];
        if (![[NSFileManager defaultManager] fileExistsAtPath:fullPath])
        {
            [[NSFileManager defaultManager] createDirectoryAtPath:fullPath
                                      withIntermediateDirectories:NO
                                                       attributes:nil
                                                            error:&error];
            if (error != nil) {
                RZFileManagerLog(@"Error:%@:",error);
            }
        }
        cacheURL = [NSURL fileURLWithPath:fullPath];
    }
    
    return cacheURL;
    
}

// Adjusted from:
// http://stackoverflow.com/questions/5996797/determine-mime-type-of-nsdata-loaded-from-a-file
+ (NSString*) mimeTypeForFileURL:(NSURL *)fileURL
{
    CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)[fileURL pathExtension], NULL);
    NSString *mimeType = (__bridge_transfer NSString*)UTTypeCopyPreferredTagWithClass(UTI, kUTTagClassMIMEType);
    CFRelease(UTI);
    
    if (!mimeType)
    {
        mimeType = @"application/octet-stream";
    }
    
    return mimeType;
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
    return [self downloadFileFromURL:remoteURL withProgressDelegateSet:progressDelegate enqueue:enqueue completion:completionBlock updateFileBlock:nil];
}

- (RZWebServiceRequest *)downloadFileFromURL:(NSURL *)remoteURL withProgressDelegateSet:(NSSet *)progressDelegate enqueue:(BOOL)enqueue completion:(RZFileManagerDownloadCompletionBlock)completionBlock updateFileBlock:(RZFileManagerDownloadUpdateFileBlock)updateBlock
{
    // Check if already downloading - if so, just add completion handlers
    // *SHOULD* only be one request for a given URL at a time... they will get the same hashed cache name
    
    RZWebServiceRequest* returnRequest = nil;
    
    NSSet *downloadsInProgress = [self requestsWithDownloadURL:remoteURL];
    if ([downloadsInProgress count])
    {
        RZWebServiceRequest *request = [downloadsInProgress anyObject];
        
        // add progress delegate
        [self addProgressDelegate:[progressDelegate anyObject] toRequests:[NSSet setWithObject:request]];
        
        // add completion block
        [self addBlock:completionBlock toRequest:request atKey:kCompletionBlockKey];
        
        return [downloadsInProgress anyObject];
    }
    
    
    
    NSURL* cacheURL = nil;
    cacheURL = [self.cacheSchema cacheURLFromRemoteURL:remoteURL];
    
    NSFileManager* diskFileManager = [NSFileManager defaultManager];
    BOOL fileExists = [diskFileManager fileExistsAtPath:[cacheURL path]];
    if (fileExists)
    {
        // Check to see if we should make a HEAD request for an update.
        if (updateBlock != nil)
        {
            NSError* error = nil;
            NSDictionary* fileAttributes = [diskFileManager attributesOfItemAtPath:[cacheURL path] error:&error];
            if (error == nil && fileAttributes)
            {
                NSDate* modifiedDate = [fileAttributes objectForKey:NSFileModificationDate];
                __weak __typeof(self)wself = self;
                RZWebServiceRequest* request = [self.webManager requestWithURL:remoteURL parameters:nil enqueue:NO completion:^(BOOL succeeded, id data, NSError *error, RZWebServiceRequest *request) {
                    if (succeeded)
                    {
                        NSString* currentLastModifiedDate = [request.responseHeaders objectForKey:@"Last-Modified"];
                        if (currentLastModifiedDate != nil)
                        {
                            static NSDateFormatter* formatter = nil;
                            if (formatter == nil)
                            {
                                formatter = [[NSDateFormatter alloc] init];
                                formatter.dateFormat = RZFileManagerDefaultServerTimeFormat;
                            }
                            
                            NSDate* currentDate = [formatter dateFromString:currentLastModifiedDate];
                            if ([currentDate compare:modifiedDate] == NSOrderedDescending)
                            {
                                RZWebServiceRequest* updateRequest = [wself fileDownloadRequestWithProgressDelegates:progressDelegate remoteURL:remoteURL cacheURL:cacheURL completionBlock:completionBlock];
                                
                                // Remove our old file.  At this point we know its stale.
                                [diskFileManager removeItemAtPath:[cacheURL path] error:nil];
                                
                                // we are making a new request, we can call the updateBlock with the newRequest/URL.
                                if (updateBlock)
                                {
                                    updateBlock(remoteURL, updateRequest);
                                }
                            }
                        }
                        else
                        {
                            RZFileManagerLog(@"Modified Date is not set for File: %@",cacheURL);
                        }
                    }
                }];
                request.httpMethod = @"HEAD";
                [self.webManager enqueueRequest:request];
                returnRequest = request;
            }
            else
            {
                // Fail Silently, We will just return our cached version.
                RZFileManagerLog(@"File Attributes could not be fetched, for file: %@ - error: %@",cacheURL, error);
            }
            // Either case we want to return the image we currently have so it's not a blank screen while we wait.
            if (completionBlock != nil)
            {
                completionBlock(YES,cacheURL,nil);
            }

            
        }
        else
        {
            // We have the file, but we don't care about updating it if its stale.
            if (completionBlock != nil)
            {
                completionBlock(YES,cacheURL,nil);
            }
        }
    }
    else
    {
        // We don'thave the file.  Lets download it.
        RZWebServiceRequest* request = [self fileDownloadRequestWithProgressDelegates:progressDelegate remoteURL:remoteURL cacheURL:cacheURL completionBlock:completionBlock];
        returnRequest = request;
    }
    
    return returnRequest;
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
    [request addProgressObserver:self];
    
    [self.uploadRequests addObject:request];
    
    if (enqueue) {
        [self enqueueUploadRequest:request];
    }
    
    return request;
}

#pragma mark - Enqueue Methods

- (void)enqueueDownloadRequest:(RZWebServiceRequest*)downloadRequest
{
    // make sure files are copied atomically.
    downloadRequest.copyToTargetAtomically = YES;
    
    if (nil == self.downloadsQueue)
    {
        [self.webManager enqueueRequest:downloadRequest];
    }
    else
    {
        [self.webManager enqueueRequest:downloadRequest inQueue:self.downloadsQueue];
    }
    
    [self postDownloadStartedNotificationForRequest:downloadRequest];
}

- (void)enqueueUploadRequest:(RZWebServiceRequest*)uploadRequest
{
    if (nil == self.uploadsQueue)
    {
        [self.webManager enqueueRequest:uploadRequest];
    }
    else
    {
        [self.webManager enqueueRequest:uploadRequest inQueue:self.uploadsQueue];
    }
    
    [self postUploadStartedNotificationForRequest:uploadRequest];
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

- (void)cancelAllDownloads
{
    // cancel all and deliver failed completion notifications
    for (RZWebServiceRequest *request in self.downloadRequests)
    {
        [request cancel];
        [self postDownloadCompletedNotificationForRequest:request successful:NO];
    }
    
    [self.downloadRequests removeAllObjects];
}

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

- (void)cancelAllUploads
{
    // cancel all and deliver failed completion notifications
    for (RZWebServiceRequest *request in self.uploadRequests)
    {
        [request cancel];
        [self postUploadCompletedNotificationForRequest:request successful:NO];
    }
    
    [self.uploadRequests removeAllObjects];
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
    if(_downloadRequests == nil)
    {
        _downloadRequests = [NSMutableSet set];
    }
    
    return _downloadRequests;
}

- (NSMutableSet*)uploadRequests
{
    if(_uploadRequests == nil)
    {
        _uploadRequests = [NSMutableSet set];
    }
    
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
    
    [[self downloadRequests] removeObject:request];
    
    NSSet *compBlocks = [request.userInfo objectForKey:kCompletionBlockKey];
    for (RZFileManagerDownloadCompletionBlock compBlock in compBlocks){
        compBlock(YES,request.targetFileURL,request);
    }
    
    [self postDownloadCompletedNotificationForRequest:request successful:YES];
}
- (void)downloadRequestFailed:(NSError *)error request:(RZWebServiceRequest *)request {
    
    [[self downloadRequests] removeObject:request];
    
    NSSet *compBlocks = [request.userInfo objectForKey:kCompletionBlockKey];
    for (RZFileManagerDownloadCompletionBlock compBlock in compBlocks){
        compBlock(NO,request.targetFileURL,request);
    }

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

- (void)webServiceRequest:(RZWebServiceRequest *)request setProgress:(float)progress
{
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

#pragma mark - Request Creation Helpers
- (RZWebServiceRequest *)fileDownloadRequestWithProgressDelegates:(NSSet *)progressDelegates
                                                        remoteURL:(NSURL *)remoteURL
                                                         cacheURL:(NSURL *)cacheURL
                                                  completionBlock:(RZFileManagerDownloadCompletionBlock)completionBlock
{
    RZWebServiceRequest * request = [self.webManager makeRequestWithURL:remoteURL target:self successCallback:@selector(downloadRequestComplete:request:) failureCallback:@selector(downloadRequestFailed:request:) parameters:nil enqueue:NO];
    [self putObject:progressDelegates inRequest:request atKey:kProgressDelegateKey];
    [self addBlock:completionBlock toRequest:request atKey:kCompletionBlockKey];
    request.targetFileURL = cacheURL;
    request.shouldCacheResponse = self.shouldCacheDownloads;
    [request addProgressObserver:self];
    
    [self.downloadRequests addObject:request];
    
    [self enqueueDownloadRequest:request];
    return request;
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

- (void)addBlock:(id)block toRequest:(RZWebServiceRequest*)request atKey:(id)key
{
    [self addObject:[block copy] toRequest:request atKey:key];
}

- (void)removeBlock:(id)block fromRequest:(RZWebServiceRequest*)request atKey:(id)key
{
    [self removeObject:block fromRequest:request atKey:key];
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
