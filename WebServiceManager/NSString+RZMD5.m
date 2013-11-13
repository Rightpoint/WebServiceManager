//
//  RZMD5.m
//  RZUtils
//
//  Created by Craig on 8/3/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "NSString+RZMD5.h"
#import <CommonCrypto/CommonDigest.h>

@implementation NSString(RZMD5)

-(NSString*) digest
{
	const char* str = [self UTF8String];
	unsigned char result[CC_MD5_DIGEST_LENGTH];
	CC_MD5(str, (CC_LONG) strlen(str), result);
	
	return [NSString stringWithFormat:
			@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
			result[0], result[1], result[2], result[3], result[4], result[5], result[6], result[7],
			result[8], result[9], result[10], result[11], result[12], result[13], result[14], result[15]
			];
	
}

@end
