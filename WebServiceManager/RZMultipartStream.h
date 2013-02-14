//
//  RZMultipartStream.h
//  plannedUp
//
//  Created by Stephen Barnes on 2/12/13.
//  Copyright (c) 2013 Raizlabs. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RZWebServiceRequest.h"

// Parameter Type Enum
typedef enum {
    RZWebServiceMultipartStreamStageInit = 0,
    RZWebServiceMultipartStreamStageHeaders,
    RZWebServiceMultipartStreamStageBody,
    RZWebServiceMultipartStreamStageWrapup,
    RZWebServiceMultipartStreamStageFinal,
    RZWebServiceMultipartStreamStageDone,
} RZWebServiceMultipartStreamStage;

@interface RZMultipartStream : NSInputStream <NSStreamDelegate>
@property (strong, nonatomic) NSArray* parameters;
@property (strong, nonatomic) RZWebServiceRequestParameter* currentStreamingParameter;
@property (readonly, nonatomic) NSString* stringBoundary;
@property (readonly, nonatomic) unsigned long long contentLength;
@property (nonatomic) RZWebServiceMultipartStreamStage currentStreamStage;
@property (strong, nonatomic) NSEnumerator *parameterEnumerator;

+ (NSString *)genRandNumberLength:(int)len;

- (id)initWithParameterArray:(NSArray *)parameters;

- (NSString *) endItemBoundary;
- (NSString *) endPOSTBoundary;
- (NSString *) beginPOSTBoundary;

@end
