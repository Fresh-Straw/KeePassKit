//
//  KPKSteamOTPGenerator.m
//  KeePassKit
//
//  Created by Michael Starke on 04.12.20.
//  Copyright © 2020 HicknHack Software GmbH. All rights reserved.
//

#import "KPKSteamOTPGenerator.h"
#import "KPKOTPGenerator_Private.h"

@implementation KPKSteamOTPGenerator

- (NSString *)_alphabet {
  return @"23456789BCDFGHJKMNPQRTVWXY";
}

- (instancetype)initWithEntry:(KPKEntry *)entry {
  self = [self init];
  if(self) {
    
  }
  return self;
}

- (BOOL)_parseEntryAttributes:(KPKEntry *)entry {
  
  
  
  return NO;
}

@end
