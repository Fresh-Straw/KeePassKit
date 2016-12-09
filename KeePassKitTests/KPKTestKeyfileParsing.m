//
//  KPKTestKeyfileParsing.m
//  MacPass
//
//  Created by Michael Starke on 13.08.13.
//  Copyright (c) 2013 HicknHack Software GmbH. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "KeePassKit.h"

@interface KPKTestKeyfileParsing : XCTestCase

@end

@implementation KPKTestKeyfileParsing

- (void)testXmlKeyfileLoadingValidFile {
  NSBundle *myBundle = [NSBundle bundleForClass:[self class]];
  NSURL *url = [myBundle URLForResource:@"Keepass2Key" withExtension:@"xml"];
  NSError *error;
  NSData *data = [NSData kpk_dataWithContentsOfKeyFile:url version:KPKDatabaseFormatKdb error:&error];
  XCTAssertNotNil(data, @"Data should be loaded");
  XCTAssertNil(error, @"No error should occur on keyfile loading");
}

- (void)testXmlKeyfileLoadingCorruptData {
  XCTAssertFalse(NO, @"Not Implemented");
}

- (void)testXmlKeyfileLoadingMissingVersion {
  XCTAssertFalse(NO, @"Not Implemented");
}

- (void)testXmlKeyfileLoadingLowerVersion {
  XCTAssertFalse(NO, @"Not Implemented");
}

- (void)testXmlKeyfilGeneration {
  NSData *data = [NSData kpk_generateKeyfiledataForFormat:KPKDatabaseFormatKdbx];
  // Test if structure is sound;
  XCTAssertNotNil(data, @"Keydata should have been generated");
}

- (void)testLegacyKeyfileGeneration {
  NSData *data = [NSData kpk_generateKeyfiledataForFormat:KPKDatabaseFormatKdb];
  // test if structure is sound;
  XCTAssertNotNil(data, @"Keydata should have been generated");
}

@end
