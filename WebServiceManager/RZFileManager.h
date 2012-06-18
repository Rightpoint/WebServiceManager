//
//  RZFileManager.h
//  WebServiceManager
//
//  Created by Joe Goullaud on 6/18/12.
//  Copyright (c) 2012 Raizlabs Corporation. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RZWebServiceRequest;

typedef void (^RZFileManagerDownloadCompletionBlock)(BOOL success, NSURL* downloadedFile, RZWebServiceRequest *request);
typedef void (^RZFileManagerUploadCompletionBlock)(BOOL success, NSURL* uploadedFile, RZWebServiceRequest *request);

@protocol RZFileProgressDelegate <NSObject>

- (void)setProgress:(double)progress;

@end

@interface RZFileManager : NSObject

// Cache Dir URL - Directory will be created if it does not exist and set to not sync/backup
@property (strong, nonatomic) NSURL *downloadCacheDirectory;
@property (assign, nonatomic) BOOL shouldCacheDownloads;                        // Turns download caching on/off - Defaults to YES

// Shared Instance Method
+ (RZFileManager*)defaultManager;

- (RZWebServiceRequest*)downloadFileFromURL:(NSURL*)remoteURL withProgressDelegate:(id<RZFileProgressDelegate>)progressDelegate completion:(RZFileManagerDownloadCompletionBlock)completionBlock;
- (RZWebServiceRequest*)downloadFileFromURL:(NSURL*)remoteURL withProgressDelegate:(id<RZFileProgressDelegate>)progressDelegate enqueue:(BOOL)enqueue completion:(RZFileManagerDownloadCompletionBlock)completionBlock;

- (RZWebServiceRequest*)uploadFile:(NSURL*)localFile toURL:(NSURL*)remoteURL withProgressDelegate:(id<RZFileProgressDelegate>)progressDelegate completion:(RZFileManagerUploadCompletionBlock)completionBlock;
- (RZWebServiceRequest*)uploadFile:(NSURL*)localFile toURL:(NSURL*)remoteURL withProgressDelegate:(id<RZFileProgressDelegate>)progressDelegate enqueue:(BOOL)enqueue completion:(RZFileManagerUploadCompletionBlock)completionBlock;

// Cancel File Transfer Requests
- (void)cancelDownloadFromURL:(NSURL*)remoteURL;
- (void)cancelUploadToURL:(NSURL*)remoteURL;


@end
