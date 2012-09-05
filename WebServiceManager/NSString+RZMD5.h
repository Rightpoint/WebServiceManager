//
//  md5.h
//  RZUtils
//
//  Created by Craig on 8/3/09.
//  Copyright 2009 Raizlabs. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface NSString(RZMD5)

// produces an MD5 hex digest of an input string
-(NSString*) digest;

@end
