//
//  KPKPair.m
//  KeePassKit
//
//  Created by Michael Starke on 12.05.17.
//  Copyright © 2017 HicknHack Software GmbH. All rights reserved.
//

#import "KPKPair.h"

@implementation KPKPair

+ (instancetype)pairWithKey:(NSString *)key value:(NSString *)value {
  return [[KPKPair alloc] initWithKey:key value:value];
}

- (instancetype)initWithKey:(NSString *)key value:(NSString *)value {
  self = [super init];
  if(self) {
    _key = [key copy];
    _value = [value copy];
  }
  return self;
}

@end

@implementation KPKMutablePair

@dynamic value;
@dynamic key;

- (void)setKey:(NSString *)key {

}

- (void)setValue:(NSString *)value {
  if(_value)
}

@end
