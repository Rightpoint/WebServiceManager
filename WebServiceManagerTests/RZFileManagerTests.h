//
//  RZFileManagerTests.h
//  WebServiceManager
//
//  Created by Alex Rouse on 6/22/12.
//  Copyright (c) 2012 Raizlabs Corporation. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import "RZWebServiceManager.h"
#import "RZFileManager.h"

@interface RZFileManagerTests : SenTestCase <RZFileProgressDelegate>

@property (nonatomic, strong) RZWebServiceManager* webServiceManager;
@property (nonatomic, assign) BOOL apiCallCompleted;

@end
