//
//  RZFileManager.h
//  WebServiceManager
//
//  Created by Joe Goullaud on 6/18/12.
//  Copyright (c) 2012 Raizlabs Corporation. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RZWebServiceRequest;
@class RZWebServiceManager;

typedef void (^RZFileManagerDownloadCompletionBlock)(BOOL success, NSURL* downloadedFile, RZWebServiceRequest *request);
typedef void (^RZFileManagerUploadCompletionBlock)(BOOL success, NSURL* uploadedFile, RZWebServiceRequest *request);

@protocol RZFileProgressDelegate <NSObject>

- (void)setProgress:(float)progress;

@end

@protocol RZCacheSchema <NSObject>

@required
- (NSURL *)cacheURLFromRemoteURL:(NSURL *)remoteURL;
- (NSURL *)cacheURLFromCustomName:(NSString *)name;
- (void)setDownloadCacheDirectory:(NSURL *)url;

@end

@interface RZFileManager : NSObject

// Cache Dir URL - Directory will be created if it does not exist and set to not sync/backup
@property (strong, nonatomic) NSURL *downloadCacheDirectory;
@property (assign, nonatomic) BOOL shouldCacheDownloads;                        // Turns download caching on/off - Defaults to YES

@property (nonatomic, weak) RZWebServiceManager* webManager;
@property (nonatomic, strong) id<RZCacheSchema> cacheSchema;


// Shared Instance Method
+ (RZFileManager*)defaultManager;

// Download File Request Methods
- (RZWebServiceRequest*)downloadFileFromURL:(NSURL*)remoteURL withProgressDelegate:(id<RZFileProgressDelegate>)progressDelegate completion:(RZFileManagerDownloadCompletionBlock)completionBlock;
- (RZWebServiceRequest*)downloadFileFromURL:(NSURL*)remoteURL withProgressDelegate:(id<RZFileProgressDelegate>)progressDelegate enqueue:(BOOL)enqueue completion:(RZFileManagerDownloadCompletionBlock)completionBlock;
- (RZWebServiceRequest*)downloadFileFromURL:(NSURL*)remoteURL withProgressDelegate:(id<RZFileProgressDelegate>)progressDelegate cacheName:(NSString *)name enqueue:(BOOL)enqueue completion:(RZFileManagerDownloadCompletionBlock)completionBlock;
- (RZWebServiceRequest*)downloadFileFromURL:(NSURL*)remoteURL withProgressDelegateSet:(NSSet *)progressDelegate enqueue:(BOOL)enqueue completion:(RZFileManagerDownloadCompletionBlock)completionBlock;
- (RZWebServiceRequest*)downloadFileFromURL:(NSURL*)remoteURL withProgressDelegateSet:(NSSet *)progressDelegate cacheName:(NSString *)name enqueue:(BOOL)enqueue completion:(RZFileManagerDownloadCompletionBlock)completionBlock;

// Upload File Request Mothods
- (RZWebServiceRequest*)uploadFile:(NSURL*)localFile toURL:(NSURL*)remoteURL withProgressDelegate:(id<RZFileProgressDelegate>)progressDelegate completion:(RZFileManagerUploadCompletionBlock)completionBlock;
- (RZWebServiceRequest*)uploadFile:(NSURL*)localFile toURL:(NSURL*)remoteURL withProgressDelegate:(id<RZFileProgressDelegate>)progressDelegate enqueue:(BOOL)enqueue completion:(RZFileManagerUploadCompletionBlock)completionBlock;
- (RZWebServiceRequest*)uploadFile:(NSURL*)localFile toURL:(NSURL*)remoteURL withProgressDelegateSet:(NSSet *)progressDelegates completion:(RZFileManagerUploadCompletionBlock)completionBlock;
- (RZWebServiceRequest*)uploadFile:(NSURL*)localFile toURL:(NSURL*)remoteURL withProgressDelegateSet:(NSSet *)progressDelegates enqueue:(BOOL)enqueue completion:(RZFileManagerUploadCompletionBlock)completionBlock;

//Download ProgressDelegateMethods
- (void)addProgressDelegate:(id<RZFileProgressDelegate>)delegate toURL:(NSURL *)remoteURL;

- (void)removeProgressDelegate:(id<RZFileProgressDelegate>)delegate fromURL:(NSURL *)remoteURL;
- (void)removeAllProgressDelegatesFromURL:(NSURL *)remoteURL;

// Upload Progress Delegate Methods
- (void)addUploadProgressDelegate:(id<RZFileProgressDelegate>)delegate toURL:(NSURL*)remoteURL;
- (void)addUploadProgressDelegate:(id<RZFileProgressDelegate>)delegate toFileURL:(NSURL*)localFileURL;

- (void)removeUploadProgressDelegate:(id<RZFileProgressDelegate>)delegate fromURL:(NSURL*)remoteURL;
- (void)removeUplaodProgressDelegate:(id<RZFileProgressDelegate>)delegate fromFileURL:(NSURL*)localFileURL;

- (void)removeAllUploadProgressDelegatesFromURL:(NSURL*)remoteURL;
- (void)removeAllUploadProgressDelegatesFromFileURL:(NSURL*)localFileURL;

// Progress Delegate Remove All Methods
- (void)removeProgressDelegateFromAllDownloads:(id<RZFileProgressDelegate>)delegate;
- (void)removeProgressDelegateFromAllUploads:(id<RZFileProgressDelegate>)delegate;
- (void)removeProgressDelegateFromAllFileRequests:(id<RZFileProgressDelegate>)delegate;

// Cancel File Transfer Requests
- (void)cancelDownloadFromURL:(NSURL*)remoteURL;
- (void)cancelUploadToURL:(NSURL*)remoteURL;
- (void)cancelUploadOfLocalFileURL:(NSURL*)localFileURL;

// Cache File Deletion Methods
- (void)deleteFileFromCacheWithName:(NSString *)name ofType:(NSString *)extension;
- (void)deleteFileFromCacheWithRemoteURL:(NSURL *)remoteURL;
- (void)deleteFileFromCacheWithURL:(NSURL *)localURL;

- (void)setProgress:(float)progress withRequest:(RZWebServiceRequest *)request;
- (NSURL *)defaultDocumentsDirectoryURL; 
@end
