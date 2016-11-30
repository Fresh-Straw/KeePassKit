//
//  KPKTestReference.m
//  MacPass
//
//  Created by Michael Starke on 15.02.14.
//  Copyright (c) 2014 HicknHack Software GmbH. All rights reserved.
//

@import  XCTest;

#import "KeePassKit.h"

@interface KPKTestReference : XCTestCase
@property (strong) KPKTree *tree;
@property (weak) KPKEntry *entry1;
@property (weak) KPKEntry *entry2;

@end

@implementation KPKTestReference

- (void)setUp {
  self.tree = [[KPKTree alloc] init];
  
  self.tree.root = [[KPKGroup alloc] init];
  self.tree.root.title = @"Root";
  
  KPKEntry *entry1 = [self.tree createEntry:self.tree.root];
  KPKEntry *entry2 = [self.tree createEntry:self.tree.root];
  [entry1 addToGroup:self.tree.root];
  [entry2 addToGroup:self.tree.root];
  self.entry1 = entry1;
  self.entry2 = entry2;
  
  self.entry2.url = @"-Entry2URL-";
  
  [super setUp];
}

- (void)tearDown {
  self.tree = nil;
  [super tearDown];
}

- (void)testCorrectUUIDReference {
  self.entry1.title = @"-Entry1Title-";
  self.entry2.title = [[NSString alloc] initWithFormat:@"Nothing{ref:t@i:%@}Changed", self.entry1.uuid.UUIDString];;
  self.entry2.url = @"-Entry2URL-";
  
  NSString *result = [self.entry2.title kpk_resolveReferencesWithTree:self.tree];
  XCTAssertTrue([result isEqualToString:@"Nothing-Entry1Title-Changed"], @"Reference with delemited UUID string matches!");
  
  NSString *undelemitedUUIDString = [self.entry1.uuid.UUIDString stringByReplacingOccurrencesOfString:@"-" withString:@""];
  self.entry2.title = [[NSString alloc] initWithFormat:@"Nothing{ref:t@i:%@}Changed", undelemitedUUIDString];;
  
  result = [self.entry2.title kpk_resolveReferencesWithTree:self.tree];
  XCTAssertTrue([result isEqualToString:@"Nothing-Entry1Title-Changed"], @"Reference with undelemtied UUID string matches!");
}

- (void)testRecursiveUUIDReference{
  self.entry1.title = [[NSString alloc] initWithFormat:@"Title1{REF:A@i:%@}", self.entry2.uuid.UUIDString];
  self.entry2.title = [[NSString alloc] initWithFormat:@"Nothing{REF:t@I:%@}Changed", self.entry1.uuid.UUIDString];
  
  NSString *result = [self.entry2.title kpk_resolveReferencesWithTree:self.tree];
  XCTAssertTrue([result isEqualToString:@"NothingTitle1-Entry2URL-Changed"], @"Replaced Strings should match");
}

- (void)testMalformedUUIDReferences {
  self.entry1.title = @"Title1";
  self.entry2.title = [[NSString alloc] initWithFormat:@"{REF:T@I:%@-}", self.entry1.uuid.UUIDString];
  
  XCTAssertNoThrow([self.entry2.title kpk_resolveReferencesWithTree:self.tree], @"Malformed UUID string does not throw exception!");
  XCTAssertTrue([[self.entry2.title kpk_resolveReferencesWithTree:self.tree] isEqualToString:self.entry2.title], @"Malformed UUID does not yield a match!");
}

- (void)testReferncePasswordByTitle {
  self.entry1.title = [[NSString alloc] initWithFormat:@"Title1{REF:A@i:%@}", self.entry2.uuid.UUIDString];
  self.entry2.title = [[NSString alloc] initWithFormat:@"Nothing{REF:t@I:%@}Changed", self.entry1.uuid.UUIDString];
  
  NSString *result = [self.entry2.title kpk_resolveReferencesWithTree:self.tree];
  XCTAssertTrue([result isEqualToString:@"NothingTitle1-Entry2URL-Changed"], @"Replaced Strings should match");
}

- (void)testReferncePasswordByCustomAttribute {
  self.entry1.title = [[NSString alloc] initWithFormat:@"Title1{REF:T@i:%@}", self.entry2.uuid.UUIDString];
  self.entry2.title = @"Entry2Title";
  
  KPKAttribute *attribute1 = [[KPKAttribute alloc] initWithKey:@"Custom1" value:@"Value1"];
  [self.entry2 addCustomAttribute:attribute1];
  KPKAttribute *attribute2 = [[KPKAttribute alloc] initWithKey:@"Custom2" value:@"Value2"];
  [self.entry2 addCustomAttribute:attribute2];
}


@end
