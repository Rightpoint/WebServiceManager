//
//  WebServiceManagerTests.m
//  WebServiceManagerTests
//
//  Created by Craig Spitzkoff on 10/22/11.
//  Copyright (c) 2011 Raizlabs Corporation. All rights reserved.
//

#import "RZWebServiceManagerTests.h"

#define kRZWebServiceTestImage      @"raizlabs-logo-sheetrock.png"
#define kRZWebServiceTestImageURL   @"http://www.raizlabs.com/cms/wp-content/uploads/2011/06/raizlabs-logo-sheetrock.png"
#define kRZWebServiceTestJSON       @"TestData.json"
#define kRZWebServiceTestJSONURL    @"http://raw.github.com/Raizlabs/WebServiceManager/master/WebServiceManagerTests/TestData.json"

@interface RZWebServiceManagerTests()
@property (nonatomic, assign) NSUInteger concurrencyCallbackCount;
@property (nonatomic, strong) NSDictionary* echoGetResult;
@property (nonatomic, strong) NSDictionary* echoPostResult;
@property (nonatomic, strong) NSDictionary* echoMultipartPostResult;
@property (nonatomic, strong) NSDictionary* responseHeaders;
@property (nonatomic, strong) NSError* error;

-(void) verifyImage:(UIImage*)image withTestNamed:(NSString*)testName;
-(void) verifyJSON:(NSDictionary*)json withTestNamed:(NSString*)testName;

@end

@implementation RZWebServiceManagerTests

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
    [[self.webServiceManager makeRequestWithKey:@"getPList" andTarget:self] setSSLCertificateType:RZWebServiceRequestSSLTrustTypeAll WithChallengeBlock:nil];
    while (!self.apiCallCompleted) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    }
}

-(void) test04GetJSON
{
    [[self.webServiceManager makeRequestWithKey:@"getJSON" andTarget:self] setSSLCertificateType:RZWebServiceRequestSSLTrustTypeAll WithChallengeBlock:nil];
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
    
    RZWebServiceRequest *plistRequest = [self.webServiceManager makeRequestWithKey:@"getPList" andTarget:self];
    [plistRequest setSSLCertificateType:RZWebServiceRequestSSLTrustTypeAll WithChallengeBlock:nil];
    [plistRequest setSuccessHandler:callback];
    
    RZWebServiceRequest *jsonRequest = [self.webServiceManager makeRequestWithKey:@"getJSON" andTarget:self];
    [jsonRequest setSSLCertificateType:RZWebServiceRequestSSLTrustTypeAll WithChallengeBlock:nil];
    [jsonRequest setSuccessHandler:callback];
    
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
    RZWebServiceRequest* request = [[RZWebServiceRequest alloc] initWithURL:[NSURL URLWithString:kRZWebServiceTestImageURL]
                                                                                     httpMethod:@"GET"
                                                                                      andTarget:self
                                                                                successCallback:@selector(logoCompleted:request:)
                                                                                failureCallback:@selector(logoFailed:)
                                                                             expectedResultType:@"Image"
                                                                                       bodyType:@"NONE"
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

-(void) test14FileStreamFailTest
{
    RZWebServiceRequest* request = [self.webServiceManager makeRequestWithKey:@"expectError" andTarget:self enqueue:NO];
    
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
    
    // make sure there is no test file
    NSError* error = nil;
    BOOL fileAvailable = [fileURL checkResourceIsReachableAndReturnError:&error];
    STAssertFalse(fileAvailable, @"Failed web request has not been removed from disk");
}

-(void) test15HEADRequest
{
    RZWebServiceRequest* request = [self.webServiceManager makeRequestWithKey:@"getLogo" andTarget:self enqueue:NO];
    request.httpMethod = @"HEAD";
    
    [self.webServiceManager enqueueRequest:request];
    
    while (!self.apiCallCompleted) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    }

}
    
-(void) test16GetContentWithDynamicPath
{
    RZWebServiceRequest *request = [self.webServiceManager makeRequestWithTarget:self andFormatKey:@"getContentWithDynamicPath", kRZWebServiceTestJSON];
    [request setSSLCertificateType:RZWebServiceRequestSSLTrustTypeAll WithChallengeBlock:nil];
    
    while (!self.apiCallCompleted) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    }
    
}

-(void) test17getContentWithDynamicPathAndHost
{
    NSString* apiKey = @"getContentWithDynamicPathAndHost";
    
    [self.webServiceManager setHost:@"https://raw.github.com" forApiKey:apiKey];

    RZWebServiceRequest  *request = [self.webServiceManager makeRequestWithTarget:self andFormatKey:apiKey, kRZWebServiceTestJSON];
    [request setSSLCertificateType:RZWebServiceRequestSSLTrustTypeAll WithChallengeBlock:nil];
    
    while (!self.apiCallCompleted) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    }
    
}

-(void) test18getContentWithDynamicPathAndHost2
{
    NSString* apiKey = @"getContentWithDynamicPathAndHost";
    
    [self.webServiceManager setHost:nil forApiKey:apiKey];
    [self.webServiceManager setDefaultHost:@"https://raw.github.com"];
    
    RZWebServiceRequest *request = [self.webServiceManager makeRequestWithTarget:self andFormatKey:apiKey, kRZWebServiceTestJSON];
    [request setSSLCertificateType:RZWebServiceRequestSSLTrustTypeAll WithChallengeBlock:nil];
    
    while (!self.apiCallCompleted) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    }
    
}

-(void) test19EchoUploadFile
{
    NSURL *fileURL = [NSURL fileURLWithPath:[[self bundlePath] stringByAppendingPathComponent:kRZWebServiceTestJSON]];
    
    RZWebServiceRequest *uploadRequest = [self.webServiceManager makeRequestWithKey:@"echoPUTFile" andTarget:self enqueue:NO];
    uploadRequest.uploadFileURL = fileURL;
    
    [self.webServiceManager enqueueRequest:uploadRequest];
    
    while (!self.apiCallCompleted) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    }
    
}

-(void) test20ManuallyAddARequestWithCompletionBlock
{
    
    // sometimes you want to add your own request, without relying on the PList. Create a request, and add it to the queue.
    RZWebServiceRequest* request = [[RZWebServiceRequest alloc] initWithURL:[NSURL URLWithString:kRZWebServiceTestImageURL]
                                                                 httpMethod:@"GET"
                                                         expectedResultType:@"Image"
                                                                   bodyType:@"NONE"
                                                                 parameters:nil
                                                                 completion:^(BOOL succeeded, id data, NSError *error, RZWebServiceRequest *request) {
                                                                     STAssertTrue(succeeded, @"Request failed.");
                                                                     
                                                                     if (succeeded)
                                                                     {
                                                                         [self logoCompleted:data request:request];
                                                                     }
                                                                     else
                                                                     {
                                                                         [self logoFailed:error];
                                                                     }
                                                                 }];
    
    [self.webServiceManager enqueueRequest:request];
    
    while (!self.apiCallCompleted) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    }
    
}

-(void) test21ExpectErrorRequestWithCompletionBlock
{
    
    // sometimes you want to add your own request, without relying on the PList. Create a request, and add it to the queue.
    RZWebServiceRequest* request = [[RZWebServiceRequest alloc] initWithURL:[NSURL URLWithString:@"http://localhost:8888/thisfiledoesnotexist"]
                                                                 httpMethod:@"GET"
                                                         expectedResultType:@"JSON"
                                                                   bodyType:@"NONE"
                                                                 parameters:nil
                                                                 completion:^(BOOL succeeded, id data, NSError *error, RZWebServiceRequest *request) {
                                                                     STAssertFalse(succeeded, @"Request succeeded when it should not have.");
                                                                     STAssertNotNil(error, @"Failed request should have returned an error.");
                                                                     
                                                                     self.apiCallCompleted = YES;
                                                                 }];
    
    [self.webServiceManager enqueueRequest:request];
    
    while (!self.apiCallCompleted) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    }
    
}

-(void) test22PreProcessingBlock
{
    // Download JSON - first create request with bogus path, then change the URL in the preprocess block
    NSURL *plistURL = [NSURL URLWithString:@"https://thiswillfail"];
        
    RZWebServiceRequest *request = [[RZWebServiceRequest alloc] initWithURL:plistURL
                                                                 httpMethod:@"GET"
                                                         expectedResultType:kRZWebserviceDataTypeJSON
                                                                   bodyType:@"NONE"
                                                                 parameters:nil
                                                                 completion:^(BOOL succeeded, id data, NSError *error, RZWebServiceRequest *request) {
                                                                     STAssertTrue(succeeded, @"Request failed - preprocess block did not succeed");
                                                                     self.apiCallCompleted = YES;
                                                                 }];
    
    // need to trust all certificates
    [request setSSLCertificateType:RZWebServiceRequestSSLTrustTypeAll WithChallengeBlock:nil];
    
    // Change the url to another url
    [request addPreProcessingBlock:^(RZWebServiceRequest *request) {
        request.url = [NSURL URLWithString:kRZWebServiceTestJSONURL];
        request.urlRequest.URL = request.url;
    }];
    
    [self.webServiceManager enqueueRequest:request];
    
    while (!self.apiCallCompleted){
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    }
}

-(void)test23PostProcessingBlock
{
    NSURL *plistURL = [NSURL URLWithString:kRZWebServiceTestJSONURL];
    
    RZWebServiceRequest *request = [[RZWebServiceRequest alloc] initWithURL:plistURL
                                                                 httpMethod:@"GET"
                                                         expectedResultType:kRZWebserviceDataTypeJSON
                                                                   bodyType:@"NONE"
                                                                 parameters:nil
                                                                 completion:^(BOOL succeeded, id data, NSError *error, RZWebServiceRequest *request) {
                                                                     
                                                                     STAssertFalse(succeeded, @"Post process block did not override success");
                                                                     STAssertEqualObjects(error.domain, @"TestErrorDomain", @"Post process block did not modify error");
                                                                     self.apiCallCompleted = YES;
                                                                     
                                                                 }];
    // need to trust all certificates
    [request setSSLCertificateType:RZWebServiceRequestSSLTrustTypeAll WithChallengeBlock:nil];
    
    // Change the succes status to fail and create an error
    [request addPostProcessingBlock:^(RZWebServiceRequest *request, __autoreleasing id *data, BOOL *succeeded, NSError *__autoreleasing *error) {
        
        STAssertTrue(*succeeded, @"The request should have succeeded when we hit post processing block");
        
        *succeeded = NO;
        *error = [NSError errorWithDomain:@"TestErrorDomain" code:100 userInfo:nil];
        
    }];
    
    [self.webServiceManager enqueueRequest:request];
    
    while (!self.apiCallCompleted){
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    }
}

- (void)test24ParameterArrays
{
    // Make a request to a bogus url, but check the query string for an expected result
    
    RZWebServiceRequest *request = [[RZWebServiceRequest alloc] initWithURL:[NSURL URLWithString:@"http://testingarrayparameters.raiz"]
                                                                 httpMethod:@"GET"
                                                         expectedResultType:kRZWebserviceDataTypeText
                                                                   bodyType:@"NONE"
                                                                 parameters:@{ @"Testing" : @[@"1", @"2", @"3"] }
                                                                 completion:^(BOOL succeeded, id data, NSError *error, RZWebServiceRequest *request) {
                                                                     
                                                                     STAssertFalse(succeeded, @"This request should have failed");
                                                                     
                                                                     NSString *queryString = [request.urlRequest.URL query];
                                                                     STAssertEqualObjects(queryString, @"Testing=1+2+3", @"Incorrect query string for proivded parameter array and delimiter");
                                                                     
                                                                     self.apiCallCompleted = YES;
                                                                 }];
    
    [self.webServiceManager enqueueRequest:request];
    
    while (!self.apiCallCompleted){
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    }
    
    // Repeat, changing the delimiter
    self.apiCallCompleted = NO;
    request = [[RZWebServiceRequest alloc] initWithURL:[NSURL URLWithString:@"http://testingarrayparameters.raiz"]
                                            httpMethod:@"GET"
                                    expectedResultType:kRZWebserviceDataTypeText
                                              bodyType:@"NONE"
                                            parameters:@{ @"Testing" : @[@"1", @"2", @"3"] }
                                            completion:^(BOOL succeeded, id data, NSError *error, RZWebServiceRequest *request) {
                                                
                                                STAssertFalse(succeeded, @"This request should have failed");
                                                
                                                NSString *queryString = [request.urlRequest.URL query];
                                                STAssertEqualObjects(queryString, @"Testing=1:2:3", @"Incorrect query string for proivded parameter array and delimiter");
                                                
                                                self.apiCallCompleted = YES;
                                            }];
    
    [request setParameterArrayDelimiter:@":"];
    
    [self.webServiceManager enqueueRequest:request];
    
    while (!self.apiCallCompleted){
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    }
}

-(void) test25EchoMultipartUploadImage
{
    // Test uploading a JSON file via multipart POST
    NSURL *fileURL = [NSURL fileURLWithPath:[[self bundlePath] stringByAppendingPathComponent:kRZWebServiceTestImage]];
    NSDictionary *params = @{ @"file" : fileURL };
    
    [self.webServiceManager makeRequestWithKey:@"echoMultipartPOSTImage" andTarget:self andParameters:params enqueue:YES];
    
    while (!self.apiCallCompleted){
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    }
}

-(void) test26EchoMultipartUploadFile
{
    // Test uploading an image via multipart POST
    NSURL *fileURL = [NSURL fileURLWithPath:[[self bundlePath] stringByAppendingPathComponent:kRZWebServiceTestJSON]];
    NSDictionary *params = @{ @"file" : fileURL };
    
    [self.webServiceManager makeRequestWithKey:@"echoMultipartPOSTFile" andTarget:self andParameters:params enqueue:YES];
    
    while (!self.apiCallCompleted) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    }
}

-(void) test27EchoMultipartPOST
{
    // Test multiple parameters sent via multipart POST
    NSURL *fileURL = [NSURL fileURLWithPath:[[self bundlePath] stringByAppendingPathComponent:kRZWebServiceTestImage]];
    NSDictionary *params = @{
                             @"imageTitle" : @"logo",
                             @"description" : @"The logo image",
                             @"image" : fileURL };
    
    [self.webServiceManager makeRequestWithKey:@"echoMultipartPOST" andTarget:self andParameters:params enqueue:YES];
    
    while (!self.apiCallCompleted) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    }
    
    // Return JSON should be
    /*{
        "postData": {
            "imageTItle": "logo",
            "description": "The logo image"
        },
        "postBinaryData": {
            "image": {
                "name": "raizlabs-logo-sheetrock.png",
                "type": "image/png",
                "tmp_name": "/Applications/MAMP/tmp/php/php30sNW7", // Variable
                "error": 0,
                "size": 22697
            }
        }
    }*/
    
    if ([self.echoMultipartPostResult isKindOfClass:[NSDictionary class]])
    {
        NSDictionary* postData = [self.echoMultipartPostResult objectForKey:@"postData"];
        if (postData && [postData isKindOfClass:[NSDictionary class]]) {
            NSString* value = [postData objectForKey:@"imageTitle"];
            if (value == nil || ![value isEqualToString:@"logo"]) {
                STAssertTrue(NO, @"Multipart POST *imageTitle* data did not echo properly.");
            }
            
            value = [postData objectForKey:@"description"];
            if (value == nil || ![value isEqualToString:@"The logo image"]) {
                STAssertTrue(NO, @"Multipart POST *description* data did not echo properly.");
            }
        }
        else {
            STAssertTrue(NO, @"Multipart POST form data did not echo properly.");
        }
        
        NSDictionary* postBinaryData = [self.echoMultipartPostResult objectForKey:@"postBinaryData"];
        if (postBinaryData && [postBinaryData isKindOfClass:[NSDictionary class]]) {
            NSDictionary* imageData = [postBinaryData objectForKey:@"image"];
            if (imageData && [imageData isKindOfClass:[NSDictionary class]]) {
                NSString* value = [imageData objectForKey:@"name"];
                if (value == nil || ![value isEqualToString:@"raizlabs-logo-sheetrock.png"]) {
                    STAssertTrue(NO, @"Multipart Binary POST *name* data did not echo properly.");
                }
                
                value = [imageData objectForKey:@"type"];
                if (value == nil || ![value isEqualToString:@"image/png"]) {
                    STAssertTrue(NO, @"Multipart Binary POST *type* data did not echo properly.");
                }
                
                NSNumber* errorValue = [imageData objectForKey:@"error"];
                if (errorValue == nil || !([errorValue integerValue] == 0)) {
                    STAssertTrue(NO, @"Multipart Binary POST data error code %d.", [errorValue integerValue]);
                }
                
                NSNumber* dataSize = [imageData objectForKey:@"size"];
                if (dataSize == nil || ([dataSize integerValue] != 22697)) {
                    STAssertTrue(NO, @"Multipart Binary POST size returned incorrect");
                }
            }
            else {
                STAssertTrue(NO, @"Multipart Binary POST form data did not echo properly.");
            }
        }
        else {
            STAssertTrue(NO, @"Multipart Binary POST form data did not echo properly.");
        }
    }
    else
    {
        STAssertTrue(NO, @"Invalid class for JSON return object.");
    }
}

#pragma mark - Verification Methods

-(void) verifyImage:(UIImage*)image withTestNamed:(NSString*)testName
{
    NSLog(@"Recieved image %lf wide by %lf high", image.size.width, image.size.height);
    
    NSURL *originalImageURL = [NSURL fileURLWithPath:[[self bundlePath] stringByAppendingPathComponent:kRZWebServiceTestImage]];
    NSData *originalImageData = [NSData dataWithContentsOfURL:originalImageURL];
    UIImage* originalImage = [UIImage imageWithData:originalImageData];
    
    STAssertTrue(((originalImage.size.width == image.size.width) && (originalImage.size.height == image.size.height))
                    , @"%@ failed: images are different sizes", testName);
    STAssertNotNil(image, @"%@ failed: no image returned", testName);
}

-(void) verifyJSON:(NSDictionary*)json withTestNamed:(NSString*)testName
{
    NSString* testDataPath = [[self bundlePath] stringByAppendingPathComponent:kRZWebServiceTestJSON];
    NSInputStream* stream = [NSInputStream inputStreamWithFileAtPath:testDataPath];

    [stream open];
    NSDictionary* testData = [NSJSONSerialization JSONObjectWithStream:stream options:0 error:nil];
    [stream close];
    
    STAssertTrue([testData isEqualToDictionary:json], @"%@: json data: %@ does not match expected results,: %@", testName, json, testData);
}

#pragma mark - Validation Callbacks

//
// Image callbacks.
//
-(void) logoCompleted:(NSObject*)photo request:(RZWebServiceRequest*)request
{
    if ([photo isKindOfClass:[UIImage class]]) {
        UIImage* image = (UIImage*)photo;
        [self verifyImage:image withTestNamed:@"logoCompleted"];
    }
    else if([photo isKindOfClass:[NSURL class]])
    {
        NSURL* url = (NSURL*)photo;
        NSData* data = [NSData dataWithContentsOfURL:url];
        UIImage* image = [[UIImage alloc] initWithData:data];
        [self verifyImage:image withTestNamed:@"logoCompleted"];
    }
    else if([request.httpMethod isEqualToString:@"HEAD"])
    {
        // only requested headers. Make sure data is empty and we have headers
        STAssertTrue(request.data.length == 0, @"Content size should be zero since a HEAD request was performed.");
        STAssertTrue(request.responseHeaders.count != 0, @"Should have received response headers for the HEAD request");
    }
    else
    {
        STAssertTrue(NO, @"Invalid class for photo object or not a HEAD request.");
    }
    
    self.apiCallCompleted = YES;
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
        
        [self verifyJSON:receivedData withTestNamed:@"jsonCompleted"];
    }
    else
    {
        STAssertTrue(NO, @"JSON operation returned wrong data type: %@", data);
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
// Echo Multipart POST callbacks
//

-(void) echoMultipartPOSTCompleted:(NSDictionary*)results
{
    self.echoMultipartPostResult = results;
    self.apiCallCompleted = YES;
}

-(void) echoMultipartPOSTFailed:(NSError*)error
{
    STAssertTrue(NO, @"echoMultipartPost failed with error: %@", error);
    self.apiCallCompleted = YES;
}

//
// Echo Multipart POST Image callbacks
//

-(void) echoMultipartPOSTImageCompleted:(NSObject*)image request:(RZWebServiceRequest*)request
{
    if ([image isKindOfClass:[UIImage class]]) {
        UIImage* recievedImage = (UIImage*)image;
        [self verifyImage:recievedImage withTestNamed:@"echoMultipartPOSTImage"];
    }
    else if([image isKindOfClass:[NSURL class]])
    {
        NSURL* url = (NSURL*)image;
        NSData* data = [NSData dataWithContentsOfURL:url];
        UIImage* recievedImage = [[UIImage alloc] initWithData:data];
        [self verifyImage:recievedImage withTestNamed:@"echoMultipartPOSTImage"];
    }
    else if([request.httpMethod isEqualToString:@"HEAD"])
    {
        // only requested headers. Make sure data is empty and we have headers
        STAssertTrue(request.data.length == 0, @"Content size should be zero since a HEAD request was performed.");
        STAssertTrue(request.responseHeaders.count != 0, @"Should have received response headers for the HEAD request");
    }
    else
    {
        STAssertTrue(NO, @"Invalid class for image object.");
    }
    
    self.apiCallCompleted = YES;
}

-(void) echoMultipartPOSTImageFailed:(NSError*)error
{
    STAssertTrue(NO, @"echoMultipartPostImage failed with error: %@", error);
    self.apiCallCompleted = YES;
}

//
// Echo Multipart POST JSON File callbacks
//

-(void) echoMultipartPOSTFileCompleted:(NSDictionary*)results request:(RZWebServiceRequest*)request
{
    if ([results isKindOfClass:[NSDictionary class]]) {
        // compare this dictionary to the included data, which should match.
        [self verifyJSON:results withTestNamed:@"echoMultipartPOSTFile"];
    }
    else
    {
        STAssertTrue(NO, @"Invalid class for JSON File return object.");
    }
    
    self.apiCallCompleted = YES;
}

-(void) echoMultipartPOSTFileFailed:(NSError*)error
{
    STAssertTrue(NO, @"echoMultipartPostFile failed with error: %@", error);
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

//
// putFile callbacks
//
-(void) echoPutFileCompleted:(NSDictionary*)results
{
    if ([results isKindOfClass:[NSDictionary class]]) {
        // compare this dictionary to the included data, which should match.
        [self verifyJSON:results withTestNamed:@"echoPutFileCompleted"];
    }
    else
    {
        STAssertTrue(NO, @"echoPutFile operation returned wrong data type: %@", results);
    }
    
    self.apiCallCompleted = YES;
}

-(void) echoPutFileFailed:(NSError*)error
{
    STAssertTrue(NO, @"echoPutFile failed with error: %@", error);
    self.apiCallCompleted = YES;
}
  
@end
