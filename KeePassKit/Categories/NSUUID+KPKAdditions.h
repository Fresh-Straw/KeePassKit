//
//  NSUUID+KeePassKit.h
//  KeePassKit
//
//  Created by Michael Starke on 25.06.13.
//  Copyright (c) 2013 HicknHack Software GmbH. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

@import Foundation;
#include "KPKPlatformIncludes.h"

#if TARGET_OS_MAC
@interface NSUUID (KPKAdditions) <KPKPasteboardWriting, KPKPasteboardReading>
#endif
#if (TARGET_OS_IPHONE || TARGET_OS_TV)
@interface NSUUID (KPKAdditions)
#endif

+ (NSUUID *)kpk_nullUUID;
+ (NSUUID *)kpk_uuidWithEncodedString:(NSString *)string;

@property (nonatomic, readonly, copy) NSData *kpk_uuidData;
@property (nonatomic, readonly, copy) NSString *kpk_encodedString;
- (instancetype)initWithEncodedUUIDString:(NSString *)string;
- (instancetype)initWithData:(NSData *)data;
/* Initsalizes with a UUID string missing any - */
- (instancetype)initWithUndelemittedUUIDString:(NSString *)string;

@end
