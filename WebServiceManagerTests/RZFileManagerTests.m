//
//  RZFileManagerTests.m
//  WebServiceManager
//
//  Created by Alex Rouse on 6/22/12.
//  Copyright (c) 2012 Raizlabs Corporation. All rights reserved.
//

#import "RZFileManagerTests.h"

@implementation RZFileManagerTests
@synthesize webServiceManager = _webServiceManager;
@synthesize apiCallCompleted = _apiCallCompleted;

-(NSString*) bundlePath
{
    return [[NSBundle bundleForClass:[RZFileManagerTests class]] bundlePath];
}

- (void)setUp
{
    [super setUp];
    
    //NSString *path = [[NSBundle bundleForClass:[WebServiceManagerTests class]] pathForResource:@"WebServiceManagerCalls" ofType:@"plist"];
    
    NSString* path = [[self bundlePath] stringByAppendingPathComponent:@"WebServiceManagerCalls.plist"];
    
    self.webServiceManager = [[RZWebServiceManager alloc] initWithCallsPath:path];
    self.apiCallCompleted = NO;
    [[RZFileManager defaultManager] setWebManager:self.webServiceManager];
    
}

- (void)tearDown
{
    // Tear-down code here.
    
    [super tearDown];
}

-(void) test01getPDFandCache
{
    [[RZFileManager defaultManager] downloadFileFromURL:[NSURL URLWithString:@"http://www.gnu.org/prep/standards/standards.pdf"] withProgressDelegate:nil enqueue:YES completion:^(BOOL success, NSURL *downloadedFile, RZWebServiceRequest *request) {
        STAssertTrue(success,@"The Request Failed");
        STAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:[downloadedFile path]],@"Cacheing failed");
        self.apiCallCompleted = YES;
        [[RZFileManager defaultManager] deleteFileFromCacheWithURL:downloadedFile];
        STAssertTrue(![[NSFileManager defaultManager] fileExistsAtPath:[downloadedFile path]],@"Deleteing download Failed");
    }];
    
    while (!self.apiCallCompleted) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    }
}
-(void) test02getPDFandCacheToCustomFileWithoutExtension
{
    [[RZFileManager defaultManager] downloadFileFromURL:[NSURL URLWithString:@"http://www.gnu.org/prep/standards/standards.pdf"] withProgressDelegate:nil cacheName:@"testNotPDF" enqueue:YES completion:^(BOOL success, NSURL *downloadedFile, RZWebServiceRequest *request) {
        STAssertTrue(success,@"The Request Failed");
        STAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:[downloadedFile path]],@"Cacheing failed");
        NSString* extensionName = [[[downloadedFile path] componentsSeparatedByString:@"."] lastObject];
        STAssertTrue([extensionName isEqualToString:@"pdf"],@"Failed to name the file the correct extension");
        self.apiCallCompleted = YES;
        [[RZFileManager defaultManager] deleteFileFromCacheWithURL:downloadedFile];
    }];
    while (!self.apiCallCompleted) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    }
}
-(void) test03workingWithProgressDelegate
{
    RZWebServiceRequest* request = [[RZFileManager defaultManager] downloadFileFromURL:[NSURL URLWithString:@"http://www.gnu.org/prep/standards/standards.pdf"] withProgressDelegate:self enqueue:NO completion:^(BOOL success, NSURL *downloadedFile, RZWebServiceRequest *request) {
        STAssertTrue(([[request.userInfo objectForKey:@"progressDelegateKey"] count] == 1),@"ProgressDelegate Not added Correctly.");
        [[RZFileManager defaultManager] deleteFileFromCacheWithURL:downloadedFile];
    }];
    
    [self.webServiceManager enqueueRequest:request];
    
    while (!self.apiCallCompleted) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    }
}


- (void)setProgress:(float)progress {
    if (progress == 1.0) {
        self.apiCallCompleted = YES;
    }
}

@end
