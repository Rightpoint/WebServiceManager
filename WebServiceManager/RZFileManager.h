//
//  RZFileManager.h
//  WebServiceManager
//
//  Created by Joe Goullaud on 6/18/12.
//  Copyright (c) 2012 Raizlabs Corporation. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MobileCoreServices/MobileCoreServices.h>

@class RZWebServiceRequest;
@class RZWebServiceManager;
@class RZCacheSchema;

typedef void (^RZFileManagerDownloadCompletionBlock)(BOOL success, NSURL* downloadedFile, RZWebServiceRequest *request);
typedef void (^RZFileManagerDownloadUpdateFileBlock)(NSURL* fileURL, RZWebServiceRequest* downloadRequest);
typedef void (^RZFileManagerUploadCompletionBlock)(BOOL success, NSURL* uploadedFile, RZWebServiceRequest *request);

@protocol RZFileProgressDelegate <NSObject>

- (void)setProgress:(float)progress;

@end

extern NSString* const RZFileManagerNotificationRemoteURLKey;
extern NSString* const RZFileManagerNotificationLocalURLKey; 
extern NSString* const RZFileManagerNotificationRequestSuccessfulKey;

extern NSString* const RZFileManagerFileDownloadStartedNotification;
extern NSString* const RZFileManagerFileDownloadCompletedNotification;
extern NSString* const RZFileManagerFileUploadStartedNotification;
extern NSString* const RZFileManagerFileUploadCompletedNotification;

@interface RZFileManager : NSObject

// Cache Dir URL - Directory will be created if it does not exist and set to not sync/backup
@property (assign, nonatomic) BOOL shouldCacheDownloads;                        // Turns download caching on/off - Defaults to YES

@property (nonatomic, weak)   RZWebServiceManager* webManager;
@property (nonatomic, strong) RZCacheSchema* cacheSchema;

@property (strong, nonatomic) NSOperationQueue *downloadsQueue;
@property (strong, nonatomic) NSOperationQueue *uploadsQueue;

// Shared Instance Method
+ (instancetype)defaultManager;

// Class methods for docs/cache directory
+ (NSURL*)defaultDocumentsDirectoryURL;
+ (NSURL*)defaultDownloadCacheURL;

// Helper method to determine a file's MIME Type and return it as a string
+ (NSString*) mimeTypeForFileURL: (NSURL *) fileURL;

// Download File Request Methods
- (RZWebServiceRequest*)downloadFileFromURL:(NSURL*)remoteURL withProgressDelegate:(id<RZFileProgressDelegate>)progressDelegate completion:(RZFileManagerDownloadCompletionBlock)completionBlock;
- (RZWebServiceRequest*)downloadFileFromURL:(NSURL*)remoteURL withProgressDelegate:(id<RZFileProgressDelegate>)progressDelegate enqueue:(BOOL)enqueue completion:(RZFileManagerDownloadCompletionBlock)completionBlock;
- (RZWebServiceRequest*)downloadFileFromURL:(NSURL*)remoteURL withProgressDelegateSet:(NSSet *)progressDelegate enqueue:(BOOL)enqueue completion:(RZFileManagerDownloadCompletionBlock)completionBlock;

// The Update Block will function as a flag as to whether or not we should perform a HEAD request to see if a newer version of an image is present.
// The Update block will contain the request for the updated image as well as the file url assuming a newer version of the image exists.
- (RZWebServiceRequest*)downloadFileFromURL:(NSURL*)remoteURL withProgressDelegateSet:(NSSet *)progressDelegate enqueue:(BOOL)enqueue completion:(RZFileManagerDownloadCompletionBlock)completionBlock updateFileBlock:(RZFileManagerDownloadUpdateFileBlock)updateBlock;

// Upload File Request Mothods
- (RZWebServiceRequest*)uploadFile:(NSURL*)localFile toURL:(NSURL*)remoteURL withProgressDelegate:(id<RZFileProgressDelegate>)progressDelegate completion:(RZFileManagerUploadCompletionBlock)completionBlock;
- (RZWebServiceRequest*)uploadFile:(NSURL*)localFile toURL:(NSURL*)remoteURL withProgressDelegate:(id<RZFileProgressDelegate>)progressDelegate enqueue:(BOOL)enqueue completion:(RZFileManagerUploadCompletionBlock)completionBlock;
- (RZWebServiceRequest*)uploadFile:(NSURL*)localFile toURL:(NSURL*)remoteURL withProgressDelegateSet:(NSSet *)progressDelegates completion:(RZFileManagerUploadCompletionBlock)completionBlock;
- (RZWebServiceRequest*)uploadFile:(NSURL*)localFile toURL:(NSURL*)remoteURL withProgressDelegateSet:(NSSet *)progressDelegates enqueue:(BOOL)enqueue completion:(RZFileManagerUploadCompletionBlock)completionBlock;

//Enqueue Methods
- (void)enqueueDownloadRequest:(RZWebServiceRequest*)downloadRequest;
- (void)enqueueUploadRequest:(RZWebServiceRequest*)uploadRequest;

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
- (void)cancelAllDownloads;
- (void)cancelDownloadFromURL:(NSURL*)remoteURL;
- (void)cancelAllUploads;
- (void)cancelUploadToURL:(NSURL*)remoteURL;
- (void)cancelUploadOfLocalFileURL:(NSURL*)localFileURL;

// Cache File Deletion Methods
- (void)deleteFileFromCacheWithRemoteURL:(NSURL *)remoteURL;
- (void)deleteFileFromCacheWithURL:(NSURL *)localURL;

- (NSSet*)requestsWithDownloadURL:(NSURL*)downloadURL;
- (NSSet*)requestsWithUploadURL:(NSURL*)uploadURL;

// Notification Posting Methods

- (void)postDownloadStartedNotificationForRequest:(RZWebServiceRequest*)request;
- (void)postUploadStartedNotificationForRequest:(RZWebServiceRequest*)request;
- (void)postDownloadCompletedNotificationForRequest:(RZWebServiceRequest*)request successful:(BOOL)success;
- (void)postUploadCompletedNotificationForRequest:(RZWebServiceRequest*)request successful:(BOOL)success;

@end
