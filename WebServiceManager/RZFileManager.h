/** This is the main RZFileManager class. This class simplifies the downloading
 and caching of files hosted on remote servers.
 
Files downloaded by the RZFileManager are automatically cached according to the
 deails of RZCacheSchema. A default cacheSchema of type RZFileCacheSchema is created
 for requests if one is not explicitly specified by the client. Custom cache behavior 
 can be specified by providing a RZCacheSchema derived object with its own 
 functionality. See RZCacheSchema for details. 
 
 
 
 */
#import <Foundation/Foundation.h>

@class RZWebServiceRequest;
@class RZWebServiceManager;
@class RZCacheSchema;

typedef void (^RZFileManagerDownloadCompletionBlock)(BOOL success, NSURL* downloadedFile, RZWebServiceRequest *request);
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

@property (nonatomic, unsafe_unretained) RZWebServiceManager* webManager;
@property (nonatomic, strong) RZCacheSchema* cacheSchema;

@property (strong, nonatomic) NSOperationQueue *downloadsQueue;
@property (strong, nonatomic) NSOperationQueue *uploadsQueue;

// Shared Instance Method
+ (RZFileManager*)defaultManager;

// Class methods for docs/cache directory
+ (NSURL*)defaultDocumentsDirectoryURL;
+ (NSURL*)defaultDownloadCacheURL;

// Download File Request Methods
- (RZWebServiceRequest*)downloadFileFromURL:(NSURL*)remoteURL withProgressDelegate:(id<RZFileProgressDelegate>)progressDelegate completion:(RZFileManagerDownloadCompletionBlock)completionBlock;
- (RZWebServiceRequest*)downloadFileFromURL:(NSURL*)remoteURL withProgressDelegate:(id<RZFileProgressDelegate>)progressDelegate enqueue:(BOOL)enqueue completion:(RZFileManagerDownloadCompletionBlock)completionBlock;
- (RZWebServiceRequest*)downloadFileFromURL:(NSURL*)remoteURL withProgressDelegateSet:(NSSet *)progressDelegate enqueue:(BOOL)enqueue completion:(RZFileManagerDownloadCompletionBlock)completionBlock;

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

- (void)setProgress:(float)progress withRequest:(RZWebServiceRequest *)request;


- (NSSet*)requestsWithDownloadURL:(NSURL*)downloadURL;
- (NSSet*)requestsWithUploadURL:(NSURL*)uploadURL;

// Notification Posting Methods

- (void)postDownloadStartedNotificationForRequest:(RZWebServiceRequest*)request;
- (void)postUploadStartedNotificationForRequest:(RZWebServiceRequest*)request;
- (void)postDownloadCompletedNotificationForRequest:(RZWebServiceRequest*)request successful:(BOOL)success;
- (void)postUploadCompletedNotificationForRequest:(RZWebServiceRequest*)request successful:(BOOL)success;

@end
