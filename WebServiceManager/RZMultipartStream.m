//
//  RZMultipartStream.m
//  plannedUp
//
//  Created by Stephen Barnes on 2/12/13.
//  Copyright (c) 2013 Raizlabs. All rights reserved.
//
//  Note: There are plans to support Multipart/Mixed for order dependent multipart
//  messages, but it is currently not supported. -SB
//

#import "RZMultipartStream.h"

@interface RZMultipartStream ()
{
    // TODO: make these properties
	id <NSStreamDelegate> delegate;
    NSStreamStatus streamStatus;
	
	CFReadStreamClientCallBack copiedCallback;
	CFStreamClientContext copiedContext;
	CFOptionFlags requestedEvents;
}
@property (nonatomic) NSUInteger readOffset;

- (NSInteger)readData:(NSData *)data intoBuffer:(uint8_t *)buffer maxLength:(NSUInteger)length;

@end

@implementation RZMultipartStream

@synthesize parameters = _parameters;
@synthesize currentStreamingParameter = _currentStreamingParameter;
@synthesize stringBoundary = _stringBoundary;
@synthesize readOffset = _readOffset;
@synthesize currentStreamStage = _currentStreamStage;
@synthesize parameterEnumerator = _parameterEnumerator;
@synthesize contentLength = _contentLength;

// Derived from http://stackoverflow.com/q/2633801/2633948#2633948
+ (NSString *)genRandNumberLength:(int)len
{
    NSString *letters = @"123456789";
    NSMutableString *randomString = [NSMutableString stringWithCapacity: len];
    for (int i=0; i<len; i++) {
        [randomString appendFormat: @"%C", [letters characterAtIndex: arc4random()%[letters length]] ];
    }
    return [randomString copy];
}

- (id)initWithParameterArray:(NSArray *)parameters
{
    self = [super init];
    if (self)
    {
        self.parameters = parameters;
        streamStatus = NSStreamStatusNotOpen;
        [self setDelegate:self];
    }
    return self;
}

- (NSString *)stringBoundary
{
    if (!_stringBoundary) {
        _stringBoundary = [NSString stringWithFormat:@"RZFormBoundary%@", [RZMultipartStream genRandNumberLength:64]];
    }
    return _stringBoundary;
}

- (unsigned long long)contentLength
{
    if (_contentLength == 0)
    {
        // Initial boundary
        _contentLength += [self.endItemBoundary dataUsingEncoding:NSUTF8StringEncoding].length;
        for (RZWebServiceRequestParameter* po in self.parameters)
        {
            // Main body content length
            _contentLength += [po contentLength];
            // Item header length
            _contentLength += po.parameterHeaderData.length;
            // Item end boundary except for last item
            if (!([self.parameters indexOfObject:po] == self.parameters.count -1))
                _contentLength += [self.endItemBoundary dataUsingEncoding:NSUTF8StringEncoding].length;
        }
        // POST end boundary
        _contentLength += [self.endPOSTBoundary dataUsingEncoding:NSUTF8StringEncoding].length;
    }
    return _contentLength;
}

#pragma mark - NSStream subclass overrides

- (void)open
{
    if (streamStatus == NSStreamStatusOpen)
        return;
    
    streamStatus = NSStreamStatusOpen;
    self.currentStreamStage = RZWebServiceMultipartStreamStageInit;
    self.parameterEnumerator = [self.parameters objectEnumerator];
    self.currentStreamingParameter = [self.parameterEnumerator nextObject];
}

- (void)close
{
    streamStatus = NSStreamStatusClosed;
}

- (id<NSStreamDelegate>)delegate
{
    return delegate;
}

- (void)setDelegate:(id<NSStreamDelegate>)aDelegate
{
    delegate = aDelegate;
    if (delegate == nil) {
    	delegate = self;
    }
}

- (void)scheduleInRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode
{
}

- (void)removeFromRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode
{
}

- (id)propertyForKey:(NSString *)key
{
    return [self.currentStreamingParameter.parameterReadStream propertyForKey:key];
}

- (BOOL)setProperty:(id)property forKey:(NSString *)key
{
    return [self.currentStreamingParameter.parameterReadStream setProperty:property forKey:key];
}

- (NSStreamStatus)streamStatus
{
    return streamStatus;
}

- (NSError *)streamError
{
    return nil;
}

#pragma mark - Helper Methods

- (NSString *) endItemBoundary
{
    return [NSString stringWithFormat:@"\r\n--%@\r\n", self.stringBoundary];
}

- (NSString *) endPOSTBoundary
{
    return [NSString stringWithFormat:@"\r\n--%@--\r\n", self.stringBoundary];
}

- (NSString *) beginPOSTBoundary
{
    return [NSString stringWithFormat:@"--%@\r\n", self.stringBoundary];    
}

- (NSInteger)readData:(NSData *)data intoBuffer:(uint8_t *)buffer maxLength:(NSUInteger)length
{
    NSRange dataRange = NSMakeRange(self.readOffset, MIN(data.length - (self.readOffset), length));
    [data getBytes:buffer range:dataRange];
    
    self.readOffset += dataRange.length;
    
    // If we're done streaming this data
    if ((self.readOffset) >= data.length) {
        [self completeStreamStage];
    }
    
    return (NSInteger)dataRange.length;
}

- (void)completeStreamStage
{
    switch (self.currentStreamStage) {
        case RZWebServiceMultipartStreamStageInit:           
            // Move to writing the header for the next parameter object
            [self setCurrentStreamStage:RZWebServiceMultipartStreamStageHeaders];
            break;
            
        case RZWebServiceMultipartStreamStageHeaders:
            // Open the parameter data for streaming
            [self.currentStreamingParameter.parameterReadStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
            [self.currentStreamingParameter.parameterReadStream open];
            
            // Move to writing body data for the current parameter object
            [self setCurrentStreamStage:RZWebServiceMultipartStreamStageBody];
            break;
            
        case RZWebServiceMultipartStreamStageBody:
            // Close the parameter data from streaming
            [self.currentStreamingParameter.parameterReadStream close];
            [self.currentStreamingParameter.parameterReadStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
            
            // If there are no more objects, move to wrapping up the Multipart stream
            if ([self.parameters indexOfObject:self.currentStreamingParameter] == self.parameters.count -1) {
                [self setCurrentStreamStage:RZWebServiceMultipartStreamStageFinal];
            }
            else {
                [self setCurrentStreamStage:RZWebServiceMultipartStreamStageWrapup];
            }
            break;
            
        case RZWebServiceMultipartStreamStageWrapup:
            self.currentStreamingParameter = [self.parameterEnumerator nextObject];
            [self setCurrentStreamStage:RZWebServiceMultipartStreamStageHeaders];
            break;
            
        case RZWebServiceMultipartStreamStageFinal:
        default:
            [self setCurrentStreamStage:RZWebServiceMultipartStreamStageDone];
            break;
    }
    
    // Reset the offset for data that has been read for the current stage
    [self setReadOffset:0];
}

#pragma mark -  NSInputStream subclass methods

- (NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)length
{
    if ([self streamStatus] == NSStreamStatusClosed) {
        return 0;
    }
    NSInteger bytesRead = 0;
    BOOL done = NO;
    while (bytesRead < length && !done)
    {
        switch (self.currentStreamStage) {
            case RZWebServiceMultipartStreamStageInit:
                
                #ifdef DEBUG
                    NSLog(@"Item Boundary Streamed: %@", self.beginPOSTBoundary);
                #endif
                
                bytesRead += [self readData:[self.beginPOSTBoundary dataUsingEncoding:NSUTF8StringEncoding] intoBuffer:&buffer[bytesRead] maxLength:(length - (NSUInteger)bytesRead)];
                break;
    
            case RZWebServiceMultipartStreamStageHeaders:
                
                #ifdef DEBUG
                    NSLog(@"Item Header Streamed: %@", [self.currentStreamingParameter headerString]);
                #endif
                
                bytesRead += [self readData:self.currentStreamingParameter.parameterHeaderData intoBuffer:&buffer[bytesRead] maxLength:(length - (NSUInteger)bytesRead)];
                break;
                
            case RZWebServiceMultipartStreamStageBody:
                
                #ifdef DEBUG
                if (self.currentStreamingParameter.parameterType == RZWebServiceRequestParamterTypeQueryString) {
                    NSLog(@"Item Value Streamed: %@", self.currentStreamingParameter.parameterValue);
                }
                #endif
                
                // Stream content from the current paramater's parameterReadStream for the body
                if ([self.currentStreamingParameter.parameterReadStream hasBytesAvailable]) {
                    bytesRead += [self.currentStreamingParameter.parameterReadStream read:&buffer[bytesRead] maxLength:(length - (NSUInteger)bytesRead)];
                }
                else {
                    [self completeStreamStage];
                }
                break;
                
            case RZWebServiceMultipartStreamStageWrapup:
                
                #ifdef DEBUG
                    NSLog(@"Item Boundary Streamed: %@", self.endItemBoundary);
                #endif
                
                // Stream itemboundary if not last item
                bytesRead += [self readData:[self.endItemBoundary dataUsingEncoding:NSUTF8StringEncoding] intoBuffer:&buffer[bytesRead] maxLength:(length - (NSUInteger)bytesRead)];
                break;
                
            case RZWebServiceMultipartStreamStageFinal:
                
                #ifdef DEBUG
                    NSLog(@"POST Boundary Streamed: %@", self.endPOSTBoundary);
                #endif
                
                // Stream Final Boundary
                bytesRead += [self readData:[self.endPOSTBoundary dataUsingEncoding:NSUTF8StringEncoding] intoBuffer:&buffer[bytesRead] maxLength:(length - (NSUInteger)bytesRead)];
                break;
                
            default:
            case RZWebServiceMultipartStreamStageDone:
                done = YES;
                break;
        }
    }
	
	return bytesRead;
}

- (BOOL)getBuffer:(uint8_t **)buffer length:(NSUInteger *)len
{
	// If you cannot return in O(1) time, return NO
	return NO;
}

- (BOOL)hasBytesAvailable
{
    return [self streamStatus] == NSStreamStatusOpen;
}

#pragma mark - Undocumented CFReadStream bridged methods
// As Documented at http://bjhomer.blogspot.com/2011/04/subclassing-nsinputstream.html

- (void)_scheduleInCFRunLoop:(CFRunLoopRef)runLoop forMode:(CFStringRef)mode
{
}

- (BOOL)_setCFClientFlags:(CFOptionFlags)inFlags
                 callback:(CFReadStreamClientCallBack)inCallback
                  context:(CFStreamClientContext *)inContext
{
	
	if (inCallback != NULL) {
		requestedEvents = inFlags;
		copiedCallback = inCallback;
		memcpy(&copiedContext, inContext, sizeof(CFStreamClientContext));
		
		if (copiedContext.info && copiedContext.retain) {
			copiedContext.retain(copiedContext.info);
		}
	}
	else {
		requestedEvents = kCFStreamEventNone;
		copiedCallback = NULL;
		if (copiedContext.info && copiedContext.release) {
			copiedContext.release(copiedContext.info);
		}
		
		memset(&copiedContext, 0, sizeof(CFStreamClientContext));
	}
	
	return YES;
}

- (void)_unscheduleFromCFRunLoop:(CFRunLoopRef)runLoop forMode:(CFStringRef)mode
{
}

#pragma mark - NSStreamDelegate methods

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
	
	assert(aStream == self.currentStreamingParameter.parameterReadStream);
	
	switch (eventCode) {
		case NSStreamEventOpenCompleted:
			if (requestedEvents & kCFStreamEventOpenCompleted) {
				copiedCallback((__bridge CFReadStreamRef)self,
							   kCFStreamEventOpenCompleted,
							   copiedContext.info);
			}
			break;
			
		case NSStreamEventHasBytesAvailable:
			if (requestedEvents & kCFStreamEventHasBytesAvailable) {
				copiedCallback((__bridge CFReadStreamRef)self,
							   kCFStreamEventHasBytesAvailable,
							   copiedContext.info);
			}
			break;
			
		case NSStreamEventErrorOccurred:
			if (requestedEvents & kCFStreamEventErrorOccurred) {
				copiedCallback((__bridge CFReadStreamRef)self,
							   kCFStreamEventErrorOccurred,
							   copiedContext.info);
			}
			break;
			
		case NSStreamEventEndEncountered:
			if (requestedEvents & kCFStreamEventEndEncountered) {
				copiedCallback((__bridge CFReadStreamRef)self,
							   kCFStreamEventEndEncountered,
							   copiedContext.info);
			}
			break;
			
		case NSStreamEventHasSpaceAvailable:
			// Not needed for a read only stream
			break;
			
		default:
			break;
	}
}

@end
