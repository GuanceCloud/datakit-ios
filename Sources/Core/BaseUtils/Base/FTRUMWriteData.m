//
//  FTRUMWriteData.m
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

#import "FTRUMWriteData.h"
#import "FTConstants.h"
#import "NSDictionary+FTCopyProperties.h"

@implementation FTRUMWriteData
- (instancetype)initWithSource:(NSString *)source tags:(NSDictionary *)tags fields:(NSDictionary *)fields
                       context:(FTRUMPropertySnapshot *)context customTagKeys:(NSSet *)tagKeys customFieldKeys:(NSSet *)fieldKeys time:(long long)time {
    if ((self = [super init])) {
        _source = [source copy];
        _tags = [NSObject ft_normalizedDictionaryWithObject:tags];
        _fields = [NSObject ft_normalizedDictionaryWithObject:fields];
        _context = context ?: [[FTRUMPropertySnapshot alloc] initWithTags:nil customKeys:nil];
        NSSet *legacy = (tagKeys == nil || fieldKeys == nil) ? FTRUMDecodeCustomKeys(_tags[FT_RUM_CUSTOM_KEYS]) : nil;
        if (tagKeys) {
            _customTagKeys = FTRUMDecodeCustomKeys(tagKeys);
        } else {
            NSMutableSet *keys = [legacy mutableCopy];
            [keys intersectSet:[NSSet setWithArray:_tags.allKeys]];
            _customTagKeys = [keys copy];
        }
        if (fieldKeys) {
            _customFieldKeys = FTRUMDecodeCustomKeys(fieldKeys);
        } else {
            NSMutableSet *keys = [legacy mutableCopy];
            [keys intersectSet:[NSSet setWithArray:_fields.allKeys]];
            _customFieldKeys = [keys copy];
        }
        _time = time;
    }
    return self;
}
- (NSDictionary *)legacyContextTags {
    NSMutableDictionary *values = [self.tags mutableCopy];
    NSMutableSet *keys = [self.customTagKeys mutableCopy];
    FTRUMMergeProperties(values, keys, self.context.tags, self.context.customKeys);
    FTRUMEncodeCustomKeys(values, self.fields, keys, self.customFieldKeys);
    NSMutableDictionary *context = [self.context.tags mutableCopy];
    [context setValue:values[FT_RUM_CUSTOM_KEYS] forKey:FT_RUM_CUSTOM_KEYS];
    return [context copy];
}
@end
