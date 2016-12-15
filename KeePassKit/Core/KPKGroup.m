//
//  KPKGroup.m
//  KeePassKit
//
//  Created by Michael Starke on 12.07.13.
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

#import "KPKGroup.h"
#import "KPKGroup_Private.h"
#import "KPKNode_Private.h"

#import "KPKAutotype.h"
#import "KPKDeletedNode.h"
#import "KPKEntry.h"
#import "KPKIconTypes.h"
#import "KPKMetaData.h"
#import "KPKTree.h"
#import "KPKTree_Private.h"
#import "KPKTimeInfo.h"

#import "NSUUID+KPKAdditions.h"

@interface KPKGroup () {
@private
  NSMutableArray *_groups;
  NSMutableArray *_entries;
}
@end

@implementation KPKGroup

@dynamic updateTiming;
@synthesize defaultAutoTypeSequence = _defaultAutoTypeSequence;
@synthesize title = _title;
@synthesize notes = _notes;

+ (BOOL)supportsSecureCoding {
  return YES;
}

+ (NSSet *)keyPathsForValuesAffectingChildren {
  return [NSSet setWithArray:@[NSStringFromSelector(@selector(groups)), NSStringFromSelector(@selector(entries)) ]];
}

+ (NSUInteger)defaultIcon {
  return KPKIconFolder;
}

- (instancetype)init {
  self = [self _init];
  return self;
}

- (instancetype)_init {
  self = [self initWithUUID:nil];
  return self;
}

- (instancetype)initWithUUID:(NSUUID *)uuid {
  self = [self _initWithUUID:uuid];
  return self;
}

- (instancetype)_initWithUUID:(NSUUID *)uuid {
  self = [super _initWithUUID:uuid];
  if(self) {
    _groups = [@[] mutableCopy];
    _entries = [@[] mutableCopy];
    _isAutoTypeEnabled = KPKInherit;
    _isSearchEnabled = KPKInherit;
    _lastTopVisibleEntry = [NSUUID kpk_nullUUID];
    //self.updateTiming = YES;
  }
  return self;
}

- (NSString*)description {
  return [NSString stringWithFormat:@"%@ [image=%ld, name=%@, %@]",
          [self class],
          self.iconId,
          self.title,
          self.timeInfo];
}

#pragma mark NSCoding
- (instancetype)initWithCoder:(NSCoder *)aDecoder {
  self = [super _initWithCoder:aDecoder];
  if(self) {
    self.updateTiming = NO;
    self.title = [aDecoder decodeObjectOfClass:[NSString class] forKey:NSStringFromSelector(@selector(title))];
    self.notes = [aDecoder decodeObjectOfClass:[NSString class] forKey:NSStringFromSelector(@selector(notes))];
    _groups = [[aDecoder decodeObjectOfClass:[NSMutableArray class] forKey:NSStringFromSelector(@selector(groups))] mutableCopy];
    _entries = [[aDecoder decodeObjectOfClass:[NSMutableArray class] forKey:NSStringFromSelector(@selector(entries))] mutableCopy];
    self.isAutoTypeEnabled = [aDecoder decodeIntegerForKey:NSStringFromSelector(@selector(isAutoTypeEnabled))];
    self.isSearchEnabled = [aDecoder decodeIntegerForKey:NSStringFromSelector(@selector(isSearchEnabled))];
    self.isExpanded = [aDecoder decodeBoolForKey:NSStringFromSelector(@selector(isExpanded))];
    self.defaultAutoTypeSequence = [aDecoder decodeObjectOfClass:[NSString class] forKey:NSStringFromSelector(@selector(defaultAutoTypeSequence))];
    self.lastTopVisibleEntry = [aDecoder decodeObjectOfClass:[NSUUID class] forKey:NSStringFromSelector(@selector(lastTopVisibleEntry))];
    
    [self _updateGroupObserving];
    [self _updateParents];
    
    self.updateTiming = YES;
  }
  return self;
}

- (void)dealloc {
  for(KPKGroup *group in _groups) {
    [self _endObservingGroup:group];
  }
  [self.undoManager removeAllActionsWithTarget:self];
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
  [super _encodeWithCoder:aCoder];
  [aCoder encodeObject:_title forKey:NSStringFromSelector(@selector(title))];
  [aCoder encodeObject:_notes forKey:NSStringFromSelector(@selector(notes))];
  [aCoder encodeObject:_groups forKey:NSStringFromSelector(@selector(groups))];
  [aCoder encodeObject:_entries forKey:NSStringFromSelector(@selector(entries))];
  [aCoder encodeInteger:_isAutoTypeEnabled forKey:NSStringFromSelector(@selector(isAutoTypeEnabled))];
  [aCoder encodeInteger:_isSearchEnabled forKey:NSStringFromSelector(@selector(isSearchEnabled))];
  [aCoder encodeBool:_isExpanded forKey:NSStringFromSelector(@selector(isExpanded))];
  [aCoder encodeObject:_defaultAutoTypeSequence forKey:NSStringFromSelector(@selector(defaultAutoTypeSequence))];
  [aCoder encodeObject:_lastTopVisibleEntry forKey:NSStringFromSelector(@selector(lastTopVisibleEntry))];
}

#pragma mark NSCopying

- (instancetype)copyWithZone:(NSZone *)zone {
  return [self _copyWithUUID:self.uuid];
}

- (instancetype)_copyWithUUID:(NSUUID *)uuid {
  KPKGroup *copy = [super _copyWithUUUD:uuid];
  copy.isAutoTypeEnabled = self.isAutoTypeEnabled;
  copy.defaultAutoTypeSequence = self.defaultAutoTypeSequence;
  copy.isSearchEnabled = self.isSearchEnabled;
  copy.isExpanded = self.isExpanded;
  copy.lastTopVisibleEntry = self.lastTopVisibleEntry;
  copy->_entries = [[[NSMutableArray alloc] initWithArray:_entries copyItems:YES] mutableCopy];
  copy->_groups = [[[NSMutableArray alloc] initWithArray:_groups copyItems:YES] mutableCopy];
  
  [copy _updateGroupObserving];
  [copy _updateParents];
  
  /* defer parent update to disable undo/redo registration */
  copy.parent = self.parent;
  return copy;
}

- (instancetype)copyWithTitle:(NSString *)titleOrNil options:(KPKCopyOptions)options {
  /* We update the UUID */
  KPKGroup *copy = [self _copyWithUUID:nil];
  
  if(nil == titleOrNil) {
    NSString *format = NSLocalizedStringFromTable(@"KPK_GROUP_COPY_%@", @"KPKLocalizable", "");
    titleOrNil = [[NSString alloc] initWithFormat:format, self.title];
  }
  copy.title = titleOrNil;
  [copy.timeInfo reset];
  return copy;
}

- (BOOL)isEqual:(id)object {
  if(self == object) {
    return YES; // Pointers match;
  }
  if(object && [object isKindOfClass:[KPKGroup class]]) {
    KPKGroup *group = (KPKGroup *)object;
    NSAssert(group, @"Equality is only possible on groups");
    return [self isEqualToGroup:group];
  }
  return NO;
}

- (BOOL)isEqualToGroup:(KPKGroup *)aGroup {
  return [self _isEqualToGroup:aGroup ignoreHierachy:NO];
}

- (BOOL)_isEqualToGroup:(KPKGroup *)aGroup ignoreHierachy:(BOOL)ignoreHierachy {
  NSAssert([aGroup isKindOfClass:[KPKGroup class]], @"No valid object supplied!");
  if(![aGroup isKindOfClass:[KPKGroup class]]) {
    return NO;
  }
  
  if(![self isEqualToNode:aGroup]) {
    return NO;
  }
  
  if((_isAutoTypeEnabled != aGroup->_isAutoTypeEnabled) || (_isSearchEnabled != aGroup->_isSearchEnabled)) {
    return NO;
  };
  
  /* stop here if only group properties are considered */
  if(ignoreHierachy) {
    return YES;
  }
  
  BOOL entryCountDiffers = _entries.count != aGroup->_entries.count;
  BOOL groupCountDiffers = _groups.count != aGroup->_groups.count;
  if( entryCountDiffers || groupCountDiffers ) {
    return NO;
  }

  for(KPKEntry *entry in _entries) {
    /* Indexes might be different, the contents of the array is important */
    if(NSNotFound == [aGroup->_entries indexOfObject:entry]) {
      return NO;
    }
    /* TODO compare entries? */
  }
  __block BOOL isEqual = YES;
  /* Indexes in groups matter, so we need to compare them */
  [_groups enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
    KPKGroup *otherGroup = obj;
    KPKGroup *myGroup = _groups[idx];
    isEqual &= [myGroup isEqualToGroup:otherGroup];
    *stop = !isEqual;
  }];
  return isEqual;
}

#pragma mark Strucural Helper
- (void)_updateParents {
  for(KPKGroup *childGroup in _groups) {
    childGroup.parent = self;
    [childGroup _updateParents];
  }
  for(KPKEntry *childEntry in _entries) {
    childEntry.parent = self;
  }
}

- (void)_updateGroupObserving {
  for(KPKGroup *group in _groups) {
    [self _beginObservingGroup:group];
  }
}

- (void)_regenerateUUIDs {
  [super _regenerateUUIDs];
  for(KPKEntry *entry in _entries) {
     [entry _regenerateUUIDs];
  }
  for(KPKGroup *group  in _groups) {
    [group _regenerateUUIDs];
  }
}

#pragma mark NSPasteboardWriting/Reading
- (NSArray<NSString *> *)writableTypesForPasteboard:(NSUIPasteboard *)pasteboard {
  return @[KPKGroupUTI];
}
+ (NSArray<NSString *> *)readableTypesForPasteboard:(NSUIPasteboard *)pasteboard {
  return @[KPKGroupUTI];
}

+ (NSPasteboardReadingOptions)readingOptionsForType:(NSString *)type pasteboard:(NSUIPasteboard *)pasteboard {
  NSAssert([type isEqualToString:KPKGroupUTI], @"Type needs to be KPKGroupUTI");
  return NSPasteboardReadingAsKeyedArchive;
}

- (id)pasteboardPropertyListForType:(NSString *)type {
  if([type isEqualToString:KPKGroupUTI]) {
    return [NSKeyedArchiver archivedDataWithRootObject:self];
  }
  return nil;
}

#pragma mark -
#pragma mark Properties
- (NSUInteger)childIndex {
  return [self.parent->_groups indexOfObject:self];
}
- (NSArray<KPKGroup *> *)groups {
  return [_groups copy];
}

- (NSArray<KPKEntry *> *)entries {
  return  [_entries copy];
}

- (NSArray<KPKNode *> *)children {
  NSMutableArray *children = [[NSMutableArray alloc] init];
  [self _collectChildren:children];
  return [children copy];
}

- (void)setNotes:(NSString *)notes {
  if(![_notes isEqualToString:notes]) {
    [[self.undoManager prepareWithInvocationTarget:self] setNotes:self.notes];
    [self touchModified];
    _notes = [notes copy];
  }
}

- (void)setTitle:(NSString *)title {
  if(![_title isEqualToString:title]) {
    [[self.undoManager prepareWithInvocationTarget:self] setTitle:self.title];
    [self touchModified];
    _title = [title copy];
  }
}

- (NSString *)defaultAutoTypeSequence {
  if(!self.hasDefaultAutotypeSequence) {
    return _defaultAutoTypeSequence;
  }
  if(self.parent) {
    return self.parent.defaultAutoTypeSequence;
  }
  NSString *defaultSequence = [self.tree defaultAutotypeSequence];
  BOOL hasDefault = defaultSequence.length > 0;
  return hasDefault ? defaultSequence : @"{USERNAME}{TAB}{PASSWORD}{ENTER}";
}

- (void)setDefaultAutoTypeSequence:(NSString *)defaultAutoTypeSequence {
  [[self.undoManager prepareWithInvocationTarget:self] setDefaultAutoTypeSequence:_defaultAutoTypeSequence];
  [self touchModified];
  _defaultAutoTypeSequence = defaultAutoTypeSequence;
}

- (BOOL)hasDefaultAutotypeSequence {
  return !(_defaultAutoTypeSequence.length > 0);
}

- (void)setIsAutoTypeEnabled:(KPKInheritBool)isAutoTypeEnabled {
  [[self.undoManager prepareWithInvocationTarget:self] setIsAutoTypeEnabled:_isAutoTypeEnabled];
  [self touchModified];
  _isAutoTypeEnabled = isAutoTypeEnabled;
}

- (void)setIsSearchEnabled:(KPKInheritBool)isSearchEnabled {
  [[self.undoManager prepareWithInvocationTarget:self] setIsSearchEnabled:_isSearchEnabled];
  [self touchModified];
  _isSearchEnabled = isSearchEnabled;
}

- (KPKFileVersion)minimumVersion {
  KPKFileVersion minimum = { KPKDatabaseFormatKdb, kKPKKdbFileVersion };
  if(self.customData.count > 0) {
    minimum.format = KPKDatabaseFormatKdbx;
    minimum.version = kKPKKdbxFileVersion4;
  }
  for(KPKGroup *group in _groups) {
    minimum = KPKFileVersionMax(minimum, group.minimumVersion);
  }
  for(KPKEntry *entry in _entries) {
    minimum = KPKFileVersionMax(minimum, entry.minimumVersion);
  }
  return minimum;
}

#pragma mark -
#pragma mark Accessors
- (NSArray *)childEntries {
  NSMutableArray *childEntries = [NSMutableArray arrayWithArray:_entries];
  for(KPKGroup *group in _groups) {
    [childEntries addObjectsFromArray:group.childEntries];
  }
  return childEntries;
}

- (NSArray *)childGroups {
  NSMutableArray *childGroups = [NSMutableArray arrayWithArray:_groups];
  for(KPKGroup *group in _groups) {
    [childGroups addObjectsFromArray:group.childGroups];
  }
  return childGroups;
}

- (KPKGroup *)asGroup {
  return self;
}

#pragma mark -
#pragma mark Group/Entry editing

- (void)_addChild:(KPKNode *)node atIndex:(NSUInteger)index {
  KPKEntry *entry = node.asEntry;
  KPKGroup *group = node.asGroup;
   
  if(group) {
    index = MAX(0, MIN(_groups.count, index));
    [self insertObject:group inGroupsAtIndex:index];
  }
  else if(entry) {
    index = MAX(0, MIN(_entries.count, index));
    [self insertObject:entry inEntriesAtIndex:index];
  }
  
  node.parent = self;
}

- (void)_removeChild:(KPKNode *)node {
  KPKEntry *entry = node.asEntry;
  KPKGroup *group = node.asGroup;
  
  if(group) {
    /* deleted objects should be registred, no undo registration */
    [self removeObjectFromGroupsAtIndex:[_groups indexOfObject:node]];
  }
  else if(entry) {
    [self removeObjectFromEntriesAtIndex:[_entries indexOfObject:node]];
  }
  node.parent = nil;
}

- (NSUInteger)_indexForNode:(KPKNode *)node {
  if(node.asGroup) {
    return [_groups indexOfObject:node];
  }
  return [_entries indexOfObject:node];
}

#pragma mark Seaching
- (KPKEntry *)entryForUUID:(NSUUID *)uuid {
  if(!uuid) {
    return nil;
  }
  for(KPKEntry *entry in _entries) {
    if([entry.uuid isEqual:uuid]) {
      return entry;
    }
  }
  for(KPKGroup *group in _groups) {
    return [group entryForUUID:uuid];
  }
  return nil;
}

- (KPKGroup *)groupForUUID:(NSUUID *)uuid {
  if(!uuid) {
    return nil;
  }
  if([self.uuid isEqual:uuid]) {
    return self;
  }
  for(KPKGroup *group in _groups) {
    return [group groupForUUID:uuid];
  }
  return nil;
}

- (NSArray<KPKEntry *> *)searchableChildEntries {
  NSMutableArray<KPKEntry *> *searchableEntries;
  if([self _isSearchable]) {
    searchableEntries = [NSMutableArray arrayWithArray:_entries];
  }
  else {
    searchableEntries = [[NSMutableArray alloc] init];
  }
  for(KPKGroup *group in _groups) {
    [searchableEntries addObjectsFromArray:group.searchableChildEntries];
  }
  return searchableEntries;
}

- (BOOL)_isSearchable {
  if(self.isTrash || self.isTrashed) {
    return NO;
  }
  switch(self.isSearchEnabled) {
    case KPKInherit:
      return self.parent ? [self.parent _isSearchable] : YES;
      
    case KPKInheritNO:
      return NO;
      
    case KPKInheritYES:
      return YES;
  }
}

#pragma mark Autotype
- (NSArray<KPKEntry *> *)autotypeableChildEntries {
  NSMutableArray<KPKEntry *> *autotypeEntries;
  if(self.isAutotypeable) {
    /* KPKEntries have their own autotype settings, hence we need to filter them as well */
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
      NSAssert([evaluatedObject isKindOfClass:[KPKEntry class]], @"entry array should contain only KPKEntry objects");
      KPKEntry *entry = evaluatedObject;
      return entry.autotype.enabled;
    }];
    autotypeEntries = [NSMutableArray arrayWithArray:[_entries filteredArrayUsingPredicate:predicate]];
  }
  else {
    autotypeEntries = [[NSMutableArray alloc] init];
  }
  for(KPKGroup *group in _groups) {
    [autotypeEntries addObjectsFromArray:[group autotypeableChildEntries]];
  }
  return autotypeEntries;
}

- (BOOL)isAutotypeable {
  if(self.isTrash || self.isTrashed){
    return NO;
  }
  switch(self.isAutoTypeEnabled) {
    case KPKInherit:
      /* Default is YES, so fall back to YES if no parent is set, aplies to root node as well */
      return self.parent ? self.parent.isAutoTypeEnabled : YES;
      
    case KPKInheritNO:
      return NO;
      
    case KPKInheritYES:
      return YES;
  }
}

#pragma mark Hierarchy

- (void)_collectChildren:(NSMutableArray *)children {
  /* TODO optimize using non-retained data structure? */
  if(!children) {
    children = [[NSMutableArray alloc] init];
  }
  [children addObjectsFromArray:_entries];
  for(KPKGroup *group in _groups) {
    [children addObject:group];
    [group _collectChildren:children];
  }
}

- (NSString *)breadcrumb {
  return [self breadcrumbWithSeparator:@"."];
}

- (NSString *)breadcrumbWithSeparator:(NSString *)separator {
  if(self.parent && (self.rootGroup != self.parent)) {
    return [[self.parent breadcrumb] stringByAppendingFormat:@" > %@", self.title];
  }
  return self.title;
}

- (NSIndexPath *)indexPath {
  if(self.parent) {
    NSUInteger myIndex = [self.parent.groups indexOfObject:self];
    NSIndexPath *parentIndexPath = [self.parent indexPath];
    NSAssert( nil != parentIndexPath, @"existing parents should always yield a indexPath");
    return [parentIndexPath indexPathByAddingIndex:myIndex];
  }
  NSUInteger indexes[] = {0,0};
  return [[NSIndexPath alloc] initWithIndexes:indexes length:(sizeof(indexes)/sizeof(NSUInteger))];
}

#pragma mark Delete

- (void)clear {
  NSUInteger groupCount = _groups.count;
  for(NSInteger index = (groupCount - 1); index > -1; index--) {
    [self removeObjectFromGroupsAtIndex:index];
  }
  NSUInteger entryCount = _entries.count;
  for(NSInteger index = (entryCount - 1); index > -1; index--) {
    [self removeObjectFromEntriesAtIndex:index];
  }
}

#pragma mark -
#pragma mark KVC

- (NSUInteger)countOfEntries {
  return _entries.count;
}

- (void)insertObject:(KPKEntry *)entry inEntriesAtIndex:(NSUInteger)index {
  [_entries insertObject:entry atIndex:index];
}

- (void)removeObjectFromEntriesAtIndex:(NSUInteger)index {
  [_entries removeObjectAtIndex:index];
}

- (NSUInteger)countOfGroups {
  return _groups.count;
}

- (void)insertObject:(KPKGroup *)group inGroupsAtIndex:(NSUInteger)index {
  [_groups insertObject:group atIndex:index];
  [self _beginObservingGroup:group];
}

- (void)removeObjectFromGroupsAtIndex:(NSUInteger)index {
  KPKGroup *group = _groups[index];
  [_groups removeObjectAtIndex:index];
  [self _endObservingGroup:group];
}


- (void)_beginObservingGroup:(KPKGroup *)group {
  [group addObserver:self forKeyPath:NSStringFromSelector(@selector(children)) options:0 context:NULL];
}

- (void)_endObservingGroup:(KPKGroup *)group {
  [group removeObserver:self forKeyPath:NSStringFromSelector(@selector(children))];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context {
  if(!object) {
    return;
  }
  if(![keyPath isEqualToString:NSStringFromSelector(@selector(children))]) {
    return;
  }
  /* just trigger a update to the children property */
  [self willChangeValueForKey:NSStringFromSelector(@selector(children))];
  [self didChangeValueForKey:NSStringFromSelector(@selector(children))];
}

@end

