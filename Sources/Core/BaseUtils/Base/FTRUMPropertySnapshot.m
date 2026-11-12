//
//  FTRUMPropertySnapshot.m
//  FTMobileSDK
//
//  Copyright 2026 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "FTRUMPropertySnapshot.h"
#import "FTConstants.h"
#import "FTJSONUtil.h"
#import "NSDictionary+FTCopyProperties.h"

// User dictionaries can contain cycles or excessive nesting. Do not let snapshot
// ownership turn malformed telemetry into unbounded recursion in the host app.
static id FTRUMCopyValue(id value, NSHashTable *ancestors, NSUInteger depth) {
    BOOL dictionary = [value isKindOfClass:NSDictionary.class];
    BOOL array = [value isKindOfClass:NSArray.class];
    BOOL set = [value isKindOfClass:NSSet.class];
    if (dictionary || array || set) {
        if (depth >= 64 || [ancestors containsObject:value]) return nil;
        [ancestors addObject:value];
        id result;
        if (dictionary) {
            NSMutableDictionary *values = [NSMutableDictionary dictionary];
            [(NSDictionary *)value enumerateKeysAndObjectsUsingBlock:^(id key, id object, BOOL *stop) {
                values[key] = FTRUMCopyValue(object, ancestors, depth + 1);
            }];
            result = [values copy];
        } else {
            NSMutableArray *values = [NSMutableArray array];
            for (id object in value) {
                id owned = FTRUMCopyValue(object, ancestors, depth + 1);
                if (owned) [values addObject:owned];
            }
            result = set ? [NSSet setWithArray:values] : [values copy];
        }
        [ancestors removeObject:value];
        return result;
    }
    // Known scalar types are immutable or safely copied. Unknown values retain
    // the existing writer validation behavior without invoking user copy code.
    if ([value isKindOfClass:NSString.class] || [value isKindOfClass:NSData.class]) return [value copy];
    return value;
}
NSDictionary *FTRUMCopyDictionary(NSDictionary *dictionary) {
    if (![dictionary isKindOfClass:NSDictionary.class]) return @{};
    NSHashTable *ancestors = [NSHashTable hashTableWithOptions:NSPointerFunctionsObjectPointerPersonality];
    return FTRUMCopyValue(dictionary, ancestors, 0);
}
@interface FTRUMPropertySnapshot ()
- (instancetype)initWithOwnedTags:(NSDictionary *)tags customKeys:(NSSet *)customKeys;
@end
NSSet<NSString *> *FTRUMDecodeCustomKeys(id value) {
    if ([value isKindOfClass:NSString.class]) {
        NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding];
        value = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
    }
    if (![value isKindOfClass:NSArray.class] && ![value isKindOfClass:NSSet.class]) return [NSSet set];
    NSMutableSet *keys = [NSMutableSet set];
    for (id key in value) {
        if ([key isKindOfClass:NSString.class] && [key length] > 0 && ![key isEqual:FT_RUM_CUSTOM_KEYS]) [keys addObject:key];
    }
    return [keys copy];
}
void FTRUMMergeProperties(NSMutableDictionary *values, NSMutableSet *keys, NSDictionary *incoming, NSSet *incomingKeys) {
    NSDictionary *safe = [incoming isKindOfClass:NSDictionary.class] ? incoming : @{};
    [keys minusSet:[NSSet setWithArray:safe.allKeys]];
    [values addEntriesFromDictionary:safe];
    for (NSString *key in incomingKeys) {
        if (safe[key] && ![key isEqual:FT_RUM_CUSTOM_KEYS]) [keys addObject:key];
    }
}
void FTRUMSetSystemProperty(NSMutableDictionary *values, NSMutableSet *keys, NSString *key, id value) {
    [values setValue:value forKey:key];
    [keys removeObject:key];
}
void FTRUMEncodeCustomKeys(NSMutableDictionary *tags, NSDictionary *fields, NSSet *tagKeys, NSSet *fieldKeys) {
    NSMutableSet *keys = [NSMutableSet set];
    for (NSString *key in tagKeys) if (tags[key] && ![tags[key] isKindOfClass:NSNull.class]) [keys addObject:key];
    for (NSString *key in fieldKeys) if (fields[key] && ![fields[key] isKindOfClass:NSNull.class]) [keys addObject:key];
    [keys removeObject:FT_RUM_CUSTOM_KEYS];
    [tags removeObjectForKey:FT_RUM_CUSTOM_KEYS];
    if (keys.count) tags[FT_RUM_CUSTOM_KEYS] = [FTJSONUtil convertToJsonDataWithObject:keys.allObjects];
}
@implementation FTRUMPropertySnapshot
- (instancetype)initWithTags:(NSDictionary *)tags customKeys:(NSSet *)customKeys {
    return [self initWithOwnedTags:FTRUMCopyDictionary(tags) customKeys:customKeys];
}
- (instancetype)initWithOwnedTags:(NSDictionary *)tags customKeys:(NSSet *)customKeys {
    if ((self = [super init])) {
        NSMutableDictionary *values = [tags mutableCopy];
        [values removeObjectForKey:FT_RUM_CUSTOM_KEYS];
        _tags = [values copy];
        NSMutableSet *keys = [FTRUMDecodeCustomKeys(customKeys) mutableCopy];
        [keys intersectSet:[NSSet setWithArray:_tags.allKeys]];
        _customKeys = [keys copy];
    }
    return self;
}
+ (instancetype)snapshotWithLegacyTags:(NSDictionary *)tags {
    return [[self alloc] initWithTags:tags customKeys:FTRUMDecodeCustomKeys(tags[FT_RUM_CUSTOM_KEYS])];
}
- (NSDictionary *)legacyTags {
    NSMutableDictionary *tags = [self.tags mutableCopy];
    FTRUMEncodeCustomKeys(tags, @{}, self.customKeys, nil);
    return [tags copy];
}
- (FTRUMPropertySnapshot *)snapshotBySettingSystemValue:(id)value forKey:(NSString *)key {
    if ((self.tags[key] == value || [self.tags[key] isEqual:value]) && ![self.customKeys containsObject:key]) return self;
    NSMutableDictionary *tags = [self.tags mutableCopy];
    NSMutableSet *keys = [self.customKeys mutableCopy];
    FTRUMSetSystemProperty(tags, keys, key, value);
    return [[FTRUMPropertySnapshot alloc] initWithOwnedTags:tags customKeys:keys];
}
@end
