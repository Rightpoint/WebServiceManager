//
//  WebServiceManagerTests.h
//  WebServiceManagerTests
//
//  Created by Craig Spitzkoff on 10/22/11.
//  Copyright (c) 2011 Raizlabs Corporation. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import "RZWebServiceManager.h"

@interface RZWebServiceManagerTests : SenTestCase 

@property (nonatomic, strong) RZWebServiceManager* webServiceManager;
@property (nonatomic, assign) BOOL apiCallCompleted;

@end
