//
//  NSURLAuthenticationChallenge+Fingerprint.m
//  WebServiceManager
//
//  Created by Craig Spitzkoff on 1/28/13.
//  Copyright (c) 2013 Raizlabs Corporation. All rights reserved.
//

#import "NSURLAuthenticationChallenge+Fingerprint.h"
#import <CommonCrypto/CommonCrypto.h>

@implementation NSURLAuthenticationChallenge (Fingerprint)

-(NSString*) sha1Fingerprint
{
    NSURLProtectionSpace *protSpace = [self protectionSpace];
    SecTrustRef currentServerTrust = [protSpace serverTrust];
    SecTrustResultType trustResult;
    SecTrustEvaluate(currentServerTrust, &trustResult);
    
    // obtain the certificate fingerprint in case we want to cache it.
    CFIndex certificateCount = SecTrustGetCertificateCount(currentServerTrust);
    
    // obtain the last certificate in the chain
    SecCertificateRef certRef = SecTrustGetCertificateAtIndex(currentServerTrust, (certificateCount - 1));
    NSData* certData = (NSData*)CFBridgingRelease(SecCertificateCopyData(certRef));

    unsigned char sha1Buffer[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1(((NSData*)certData).bytes, (CC_LONG) certData.length, sha1Buffer);
    NSMutableString *fingerprint = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 3];
    for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; ++i)
        [fingerprint appendFormat:@"%02x ",sha1Buffer[i]];
    
    NSString* strippedFingerprint  = [fingerprint stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    
    return strippedFingerprint;
}

@end
