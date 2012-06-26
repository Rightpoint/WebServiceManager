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

@interface RZFileManager : NSObject

// Cache Dir URL - Directory will be created if it does not exist and set to not sync/backup
@property (strong, nonatomic) NSURL *downloadCacheDirectory;
@property (assign, nonatomic) BOOL shouldCacheDownloads;                        // Turns download caching on/off - Defaults to YES

@property (nonatomic, weak) RZWebServiceManager* webManager;


// Shared Instance Method
+ (RZFileManager*)defaultManager;

- (RZWebServiceRequest*)downloadFileFromURL:(NSURL*)remoteURL withProgressDelegate:(id<RZFileProgressDelegate>)progressDelegate completion:(RZFileManagerDownloadCompletionBlock)completionBlock;
- (RZWebServiceRequest*)downloadFileFromURL:(NSURL*)remoteURL withProgressDelegate:(id<RZFileProgressDelegate>)progressDelegate enqueue:(BOOL)enqueue completion:(RZFileManagerDownloadCompletionBlock)completionBlock;
- (RZWebServiceRequest*)downloadFileFromURL:(NSURL*)remoteURL withProgressDelegate:(id<RZFileProgressDelegate>)progressDelegate cacheName:(NSString *)name enqueue:(BOOL)enqueue completion:(RZFileManagerDownloadCompletionBlock)completionBlock;
- (RZWebServiceRequest*)downloadFileFromURL:(NSURL*)remoteURL withProgressDelegateSet:(NSSet *)progressDelegate enqueue:(BOOL)enqueue completion:(RZFileManagerDownloadCompletionBlock)completionBlock;
- (RZWebServiceRequest*)downloadFileFromURL:(NSURL*)remoteURL withProgressDelegateSet:(NSSet *)progressDelegate cacheName:(NSString *)name enqueue:(BOOL)enqueue completion:(RZFileManagerDownloadCompletionBlock)completionBlock;

- (RZWebServiceRequest*)uploadFile:(NSURL*)localFile toURL:(NSURL*)remoteURL withProgressDelegate:(id<RZFileProgressDelegate>)progressDelegate completion:(RZFileManagerUploadCompletionBlock)completionBlock;
- (RZWebServiceRequest*)uploadFile:(NSURL*)localFile toURL:(NSURL*)remoteURL withProgressDelegate:(id<RZFileProgressDelegate>)progressDelegate enqueue:(BOOL)enqueue completion:(RZFileManagerUploadCompletionBlock)completionBlock;

//ProgressDelegateMethods
- (void)removeProgressDelegate:(id<RZFileProgressDelegate>)delegate fromURL:(NSURL *)remoteURL;
- (void)removeAllProgressDelegatesFromURL:(NSURL *)remoteURL;

- (void)addProgressDelegate:(id<RZFileProgressDelegate>)delegate toURL:(NSURL *)remoteURL;


// Cancel File Transfer Requests
- (void)cancelDownloadFromURL:(NSURL*)remoteURL;
- (void)cancelUploadToURL:(NSURL*)remoteURL;

- (void)deleteFileFromCacheWithName:(NSString *)name ofType:(NSString *)extension;
- (void)deleteFileFromCacheWithURL:(NSURL *)remoteURL;

- (void)setProgress:(float)progress withRequest:(RZWebServiceRequest *)request;
- (NSURL *)defaultDocumentsDirectoryURL; 
@end
