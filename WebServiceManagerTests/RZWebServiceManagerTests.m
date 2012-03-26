//
//  WebServiceManagerTests.m
//  WebServiceManagerTests
//
//  Created by Craig Spitzkoff on 10/22/11.
//  Copyright (c) 2011 Raizlabs Corporation. All rights reserved.
//

#import "RZWebServiceManagerTests.h"

@interface RZWebServiceManagerTests()
@property (nonatomic, assign) NSUInteger concurrencyCallbackCount;
@property (nonatomic, strong) NSDictionary* echoGetResult;
@property (nonatomic, strong) NSDictionary* echoPostResult;
@property (nonatomic, strong) NSDictionary* responseHeaders;
@property (nonatomic, strong) NSError* error;
@end

@implementation RZWebServiceManagerTests
@synthesize apiCallCompleted = _apiCallCompleted;
@synthesize webServiceManager = _webServiceManager;
@synthesize concurrencyCallbackCount = _concurrencyCallbackCount;
@synthesize echoGetResult = _echoGetResult;
@synthesize echoPostResult = _echoPostResult;
@synthesize responseHeaders = _responseHeaders;
@synthesize error = _error;

-(NSString*) bundlePath
{
    return [[NSBundle bundleForClass:[RZWebServiceManagerTests class]] bundlePath];
}

- (void)setUp
{
    [super setUp];
    
    //NSString *path = [[NSBundle bundleForClass:[WebServiceManagerTests class]] pathForResource:@"WebServiceManagerCalls" ofType:@"plist"];
    
    NSString* path = [[self bundlePath] stringByAppendingPathComponent:@"WebServiceManagerCalls.plist"];
    
    self.webServiceManager = [[RZWebServiceManager alloc] initWithCallsPath:path];
    self.apiCallCompleted = NO;
}

- (void)tearDown
{
    // Tear-down code here.
    
    [super tearDown];
}

- (void)test01GetLogo
{
    [self.webServiceManager makeRequestWithKey:@"getLogo" andTarget:self];
    
    while (!self.apiCallCompleted) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    }

}

-(void) test02GetContent
{
    [self.webServiceManager makeRequestWithKey:@"getContent" andTarget:self];
    
    while (!self.apiCallCompleted) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    }
}

-(void) test03GetPlist
{
    [self.webServiceManager makeRequestWithKey:@"getPList" andTarget:self];
    while (!self.apiCallCompleted) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    }
}

-(void) test04GetJSON
{
    [self.webServiceManager makeRequestWithKey:@"getJSON" andTarget:self];
    while (!self.apiCallCompleted) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    }
}

// What happens when we make many calls at once? They should queue up, one at a time. This will 
// test this feature, and override the callbacks specified in the plist so we can count the callbacks. 
-(void) test05Concurrency
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

-(void) test06RequestWithGetArguments
{
    NSDictionary* parameters = [NSDictionary dictionaryWithObjectsAndKeys:@"Hello, world!", @"hello", 
                                [NSNumber numberWithInt:123456], @"integerKey",
                                [NSNumber numberWithFloat:1234.567], @"floatKey", nil];
    
    [self.webServiceManager makeRequestWithKey:@"echoGET" andTarget:self andParameters:parameters];
    
    while (!self.apiCallCompleted) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    }
    
    // loop through the keys and make sure the dictionaries have equal values. 
    STAssertTrue(self.echoGetResult.count == parameters.count, @"Get Request parameter list was not echoed correctly. There may be a problem sending the URL parameters." );
    

}
-(void) test07RequestWithPOSTArguments
{
    NSDictionary* parameters = [NSDictionary dictionaryWithObjectsAndKeys:@"Hello, world!", @"hello", 
                                [NSNumber numberWithInt:123456], @"integerKey",
                                [NSNumber numberWithFloat:1234.567], @"floatKey", nil];
    
    [self.webServiceManager makeRequestWithKey:@"echoPOST" andTarget:self andParameters:parameters];
    
    while (!self.apiCallCompleted) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    }
    
    // loop through the keys and make sure the dictionaries have equal values. 
    STAssertTrue(self.echoPostResult.count == parameters.count, @"Get Request parameter list was not echoed correctly. There may be a problem sending the URL parameters." );
    
    
}

-(void) test08ManuallyAddARequest
{

    // sometimes you want to add your own request, without relying on the PList. Create a request, and add it to the queue.
    RZWebServiceRequest* request = [[RZWebServiceRequest alloc] initWithURL:[NSURL URLWithString:@"http://www.raizlabs.com/cms/wp-content/uploads/2011/06/raizlabs-logo-sheetrock.png"]
                                                                                     httpMethod:@"GET"
                                                                                      andTarget:self successCallback:@selector(logoCompleted:request:)
                                                                                failureCallback:@selector(logoFailed:)
                                                                             expectedResultType:@"Image"
                                                                                  andParameters:nil];
    
    [self.webServiceManager enqueueRequest:request];
    
    while (!self.apiCallCompleted) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    }
    
}

-(void) test09ResponseHeaders
{
    
    NSDictionary* parameters = [NSDictionary dictionaryWithObjectsAndKeys:@"Hello, world!", @"hello", 
                                [NSNumber numberWithInt:123456], @"integerKey",
                                [NSNumber numberWithFloat:1234.567], @"floatKey", nil];
    
    [self.webServiceManager makeRequestWithKey:@"echoPOSTExtended" andTarget:self andParameters:parameters];
    
    while (!self.apiCallCompleted) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    }
    
    // ensure the headers were made available. 
    STAssertNotNil(self.responseHeaders, @"Reponse headers were not populated");
    
}

// test to see if this works on a GCD dispatched thread
-(void) test10GCDGet
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
         [self.webServiceManager makeRequestWithKey:@"getContent" andTarget:self];
    });
    
    while (!self.apiCallCompleted) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    }
    

}

-(void) test11SendHeaders
{
    NSString* header1 = @"123456789";
    NSString* header2 = @"This is a test header";
    NSString* header3 = @"This is another test header";
    
    RZWebServiceRequest* request = [self.webServiceManager makeRequestWithKey:@"echoHeaders" andTarget:self];
    request.headers = [NSDictionary dictionaryWithObjectsAndKeys:header1,@"header1", 
                      header2, @"header2",
                      header3, @"header3", nil];
    
    while (!self.apiCallCompleted) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    }       
    
   ;
    
    
    STAssertTrue([[self.echoGetResult objectForKey:@"header1"] isEqualToString:header1], @"Headers were not sent successfully");

    STAssertTrue([[self.echoGetResult objectForKey:@"header2"] isEqualToString:header2], @"Headers were not sent successfully");
    
    STAssertTrue([[self.echoGetResult objectForKey:@"header3"] isEqualToString:header3], @"Headers were not sent successfully");
}

-(void) test12ExpectError
{
    [self.webServiceManager makeRequestWithKey:@"expectError" andTarget:self];
    
    while (!self.apiCallCompleted) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    }       
    
    STAssertNotNil(self.error, @"expectError did not return an error condition");
}

-(void) test13FileStreamTest
{
    RZWebServiceRequest* request = [self.webServiceManager makeRequestWithKey:@"getLogo" andTarget:self enqueue:NO];

    NSString* testFilename = @"testFile.dat";
    
    NSURL* documentsDir = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
    NSURL* fileURL = [documentsDir URLByAppendingPathComponent:testFilename];

    // remove any previous file. 
    [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
    
    // make sure the directory exists.
    [[NSFileManager defaultManager] createDirectoryAtURL:documentsDir withIntermediateDirectories:YES attributes:nil error:nil];
    
    request.targetFileURL = fileURL;
    
    [self.webServiceManager enqueueRequest:request];
    
    while (!self.apiCallCompleted) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    }
}

-(void) test14HEADRequest
{
    RZWebServiceRequest* request = [self.webServiceManager makeRequestWithKey:@"getLogo" andTarget:self enqueue:NO];
    request.httpMethod = @"HEAD";
    
    [self.webServiceManager enqueueRequest:request];
    
    while (!self.apiCallCompleted) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    }

}
    
-(void) test15GetContentWithDynamicPath
{
    [self.webServiceManager makeRequestWithTarget:self andFormatKey:@"getContentWithDynamicPath", @"TestData.json"];
    
    while (!self.apiCallCompleted) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    }
    
}

//
// Image callbacks. 
//
-(void) logoCompleted:(NSObject*)photo request:(RZWebServiceRequest*)request
{
    if ([photo isKindOfClass:[UIImage class]]) {
        
        UIImage* image = (UIImage*)photo;
        
        NSLog(@"Recieved photo %lf wide by %lf high", image.size.width, image.size.height);
        self.apiCallCompleted = YES;
        
        STAssertNotNil(image, @"getLogo failed: no image returned");
    }
    else if([photo isKindOfClass:[NSURL class]])
    {
        NSURL* url = (NSURL*)photo;
        NSData* data = [NSData dataWithContentsOfURL:url];
        UIImage* image = [[UIImage alloc] initWithData:data];
        
        // make sure we can optn the file provided by streaming to disk
        
        NSLog(@"Recieved photo %lf wide by %lf high", image.size.width, image.size.height);
        self.apiCallCompleted = YES;
        
        STAssertNotNil(image, @"getLogo failed: no image returned");
    }
    else if([request.httpMethod isEqualToString:@"HEAD"])
    {
        // only requested headers. Make sure data is empty and we have headers
        STAssertTrue(request.data.length == 0, @"Content size should be zero since a HEAD request was performed.");
        STAssertTrue(request.responseHeaders.count != 0, @"Should have received response headers for the HEAD request");
        
        self.apiCallCompleted = YES;
    }
 
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

-(void) echoGetCompleted:(NSDictionary*)results
{
    self.echoGetResult = results;
    self.apiCallCompleted = YES;
}

-(void) echoGetFailed:(NSError*)error
{
    STAssertTrue(NO, @"echoGet failed with error: %@", error);
    self.apiCallCompleted = YES;
}

//
// Echo POST callbacks
//

-(void) echoPostCompleted:(NSDictionary*)results
{
    self.echoPostResult = results;
    self.apiCallCompleted = YES;
}

-(void) echoPostCompleted:(NSDictionary*)results request:(RZWebServiceRequest*)request
{
    self.echoPostResult = results;
    self.responseHeaders = request.responseHeaders;
    
    self.apiCallCompleted = YES;
}

-(void) echoPostFailed:(NSError*)error
{
    STAssertTrue(NO, @"echoPost failed with error: %@", error);
    self.apiCallCompleted = YES;
}

//
// expectError callbacks
//
-(void) expectError:(NSError*)error
{
    self.error = error;
    self.apiCallCompleted = YES;
}

-(void) expectErrorCompleted:(NSDictionary*)data
{
    self.apiCallCompleted = YES;
}
  
@end
