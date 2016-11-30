//
//  NSData+KPKResize.m
//  KeePassKit
//
//  Created by Michael Starke on 01/11/2016.
//  Copyright © 2016 HicknHack Software GmbH. All rights reserved.
//

#import "NSData+KPKKeyComputation.h"
#import <CommonCrypto/CommonCrypto.h>

@implementation NSData (KPKKeyComputation)

- (NSData *)kpk_resizeKeyDataTo:(NSUInteger)length {
  return [self kpk_resizeKeyDataRange:NSMakeRange(0, self.length) toLength:length];
}

- (NSData *)kpk_resizeKeyDataRange:(NSRange)range toLength:(NSUInteger)length {
  
  NSAssert((range.location + range.length) <= self.length, @"");
  
  if(length == 0) {
    return [NSData data]; // empty data!
  }
  const uint8_t *byteOffset = (self.bytes + range.location);
  if(length <= 32) {
    uint8_t sha256Hash[32];
    CC_SHA256(byteOffset, (CC_LONG)range.length, sha256Hash);
    return [NSData dataWithBytes:sha256Hash length:32];
  }
  uint8_t sha512Hash[64];
  CC_SHA512(byteOffset, (CC_LONG)range.length, sha512Hash);
  
  if(length <= 64 ) {
    return [NSData dataWithBytes:sha512Hash length:length];
  }
  
  uint8_t output[length];
  NSUInteger position = 0;
  uint64_t count = 0;
  while(position < length) {
    uint8_t hmac[32];
    uint64_t LECount = CFSwapInt64HostToLittle(count);
    CCHmac(kCCHmacAlgSHA256, &LECount, 8, sha512Hash, 64, hmac);
    NSUInteger copyLength = MIN(length - position, 32);
    memcpy(output+position, hmac, copyLength);
    position += copyLength;
    count++;
  }
  
  return [NSData dataWithBytes:output length:length];
}

- (NSData *)kpk_hmacKeyForIndex:(uint64_t)index {
  //NSAssert(self.length == 64, @"Invalid data size. HeaderMac required 64 byte of data!");
  
  /* ensure endianess */
  index = CFSwapInt64LittleToHost(index);
  CC_SHA512_CTX context;
  CC_SHA512_Init(&context);
  CC_SHA512_Update(&context, &index, sizeof(uint64_t));
  CC_SHA512_Update(&context, self.bytes, (CC_LONG)self.length);
  uint8_t buffer[64];
  CC_SHA512_Final(buffer, &context);
  return [NSData dataWithBytes:buffer length:64];
  return nil;
}

- (NSData *)kpk_headerHmacWithKey:(NSData *)key {
  key = [key kpk_hmacKeyForIndex:UINT64_MAX];
  uint8_t buffer[32];
  CCHmac(kCCHmacAlgSHA256, key.bytes, key.length, self.bytes, self.length, buffer);
  return [NSData dataWithBytes:buffer length:32];
}

@end
