//
//  WebServiceManagerTests.m
//  WebServiceManagerTests
//
//  Created by Craig Spitzkoff on 10/22/11.
//  Copyright (c) 2011 Raizlabs Corporation. All rights reserved.
//

#import "WebServiceManagerTests.h"

@interface WebServiceManagerTests()
@property (nonatomic, assign) NSUInteger concurrencyCallbackCount;
@end

@implementation WebServiceManagerTests
@synthesize apiCallCompleted = _apiCallCompleted;
@synthesize webServiceManager = _webServiceManager;
@synthesize concurrencyCallbackCount = _concurrencyCallbackCount;

-(NSString*) bundlePath
{
    return [[NSBundle bundleForClass:[WebServiceManagerTests class]] bundlePath];
}

- (void)setUp
{
    [super setUp];
    
    //NSString *path = [[NSBundle bundleForClass:[WebServiceManagerTests class]] pathForResource:@"WebServiceManagerCalls" ofType:@"plist"];
    
    NSString* path = [[self bundlePath] stringByAppendingPathComponent:@"WebServiceManagerCalls.plist"];
    
    self.webServiceManager = [[WebServiceManager alloc] initWithCallsPath:path];
    self.apiCallCompleted = NO;
}

- (void)tearDown
{
    // Tear-down code here.
    
    [super tearDown];
}
- (void)test1GetLogo
{
    [self.webServiceManager makeRequestWithKey:@"getLogo" andTarget:self];
    
    while (!self.apiCallCompleted) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    }

}

-(void) test2GetContent
{
    [self.webServiceManager makeRequestWithKey:@"getContent" andTarget:self];
    
    while (!self.apiCallCompleted) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    }
}

-(void) test3GetPlist
{
    [self.webServiceManager makeRequestWithKey:@"getPList" andTarget:self];
    while (!self.apiCallCompleted) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    }
}

-(void) test4GetJSON
{
    [self.webServiceManager makeRequestWithKey:@"getJSON" andTarget:self];
    while (!self.apiCallCompleted) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    }
}

// What happens when we make many calls at once? They should queue up, one at a time. This will 
// test this feature, and override the callbacks specified in the plist so we can count the callbacks. 
-(void) test5Concurrency
{
    self.concurrencyCallbackCount = 0;
    SEL callback = @selector(concurrencyCallback:);
    
    [[self.webServiceManager makeRequestWithKey:@"getLogo" andTarget:self] setSuccessHandler:callback];
    [[self.webServiceManager makeRequestWithKey:@"getContent" andTarget:self] setSuccessHandler:callback];
    [[self.webServiceManager makeRequestWithKey:@"getPList" andTarget:self] setSuccessHandler:callback];
    [[self.webServiceManager makeRequestWithKey:@"getJSON" andTarget:self] setSuccessHandler:callback];   
    
    while (!self.apiCallCompleted) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    }
}

-(void) test6RequestWithGetArguments
{
    NSDictionary* parameters = [NSDictionary dictionaryWithObjectsAndKeys:@"Hello, world!", @"hello", 
                                [NSNumber numberWithInt:123456], @"integerKey",
                                [NSNumber numberWithFloat:1234.567], @"floatKey", nil];
    
    [self.webServiceManager makeRequestWithKey:@"echoGET" andTarget:self andParameters:parameters];
    
    while (!self.apiCallCompleted) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    }
}

//
// Image callbacks. 
//
-(void) logoCompleted:(UIImage*)photo
{
    NSLog(@"Recieved photo %lf wide by %lf high", photo.size.width, photo.size.height);
    self.apiCallCompleted = YES;
    
    STAssertNotNil(photo, @"getLogo failed: no image returned");
}

-(void) logoFailed:(NSError*)error
{
    STAssertTrue(NO, @"getLogo failed with error: %@", error);
    self.apiCallCompleted = YES; 

}

//
// Content Callbakcks
//
-(void) contentCompleted:(NSString*) content
{
    NSLog(@"Received Content: %@", content);
    
    STAssertNotNil(content, @"getContent failed: no content returned");
    
    self.apiCallCompleted = YES;     
}

-(void) contentFailed:(NSError*)error
{
    STAssertTrue(NO, @"getContent failed with error: %@", error);
    self.apiCallCompleted = YES; 
}

// PList Callbacks
-(void) plistCompleted:(id) data
{
    if ([data isKindOfClass:[NSDictionary class]]) {
        
        // compare this dictionary to the included data, which should match. 
        NSDictionary* receivedData = (NSDictionary*)data;
        
        NSString* testDataPath = [[self bundlePath] stringByAppendingPathComponent:@"TestData.plist"];
        NSDictionary* testData = [NSDictionary dictionaryWithContentsOfFile:testDataPath];
        
        STAssertTrue([testData isEqualToDictionary:receivedData], @"plist data: %@ does not match expected results,: %@", receivedData, testData);
        
    }
    else
    {
        STAssertTrue(NO, @"plist operation returned wrong data type: %@", data);
    }
    
    self.apiCallCompleted = YES;
}

-(void) plistFailed:(NSError*)error
{
    STAssertTrue(NO, @"getPList failed with error: %@", error);
    self.apiCallCompleted = YES; 
}

// JSON Callbacks
-(void) jsonCompleted:(id)data
{
    if ([data isKindOfClass:[NSDictionary class]]) {
        
        // compare this dictionary to the included data, which should match. 
        NSDictionary* receivedData = (NSDictionary*)data;
        
        NSString* testDataPath = [[self bundlePath] stringByAppendingPathComponent:@"TestData.json"];
        NSInputStream* stream = [NSInputStream inputStreamWithFileAtPath:testDataPath];
        [stream open];
        NSDictionary* testData = [NSJSONSerialization JSONObjectWithStream:stream options:0 error:nil];
        [stream close];
        
        STAssertTrue([testData isEqualToDictionary:receivedData], @"json data: %@ does not match expected results,: %@", receivedData, testData);
        
    }
    else
    {
        STAssertTrue(NO, @"plist operation returned wrong data type: %@", data);
    }
    
    self.apiCallCompleted = YES;
}

-(void) jsonFailed:(NSError*)error
{
    STAssertTrue(NO, @"getJSON failed with error: %@", error);
    self.apiCallCompleted = YES; 
}

-(void) concurrencyCallback:(id)data
{
    self.concurrencyCallbackCount++;
    
    if (self.concurrencyCallbackCount >= 4) {
        self.apiCallCompleted = YES;
    }
}

//
// Echo GET callbacks
//

-(void) echoGetCompleted:(NSString*)results
{
    self.apiCallCompleted = YES;
}

-(void) echoGetFailed:(NSError*)error
{
    STAssertTrue(NO, @"echoGet failed with error: %@", error);
    self.apiCallCompleted = YES;
}
@end
