//
//  FTWebViewLogEventMapper.m
//  GuanceSDK
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

#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif

#import "FTWebViewLogEventMapper.h"
#import "FTConstants.h"
#import "FTJSONUtil.h"
#import "NSDate+FTUtil.h"
#import <CoreFoundation/CoreFoundation.h>
#import <limits.h>
#import <math.h>

static const long long FTNanosecondsPerMillisecond = 1000000LL;

@implementation FTWebViewLogEvent
@end

@implementation FTWebViewLogEventMapper

+ (FTWebViewLogEvent *)mapEvent:(NSDictionary *)event {
    if (![event isKindOfClass:NSDictionary.class]) {
        return nil;
    }
    id rawMessage = [self valueAtPath:@"message" inObject:event];
    if ([self isNull:rawMessage]) {
        return nil;
    }

    NSMutableDictionary *tags = [NSMutableDictionary dictionary];
    NSMutableDictionary *fields = [NSMutableDictionary dictionary];
    NSMutableSet<NSString *> *consumedKeys = [NSMutableSet setWithArray:@[
        @"date", @"type", @"custom_keys", FT_IS_WEBVIEW
    ]];

    [self mapCommonTags:event tags:tags consumedKeys:consumedKeys];
    [self mapCommonFields:event fields:fields consumedKeys:consumedKeys];
    [self mapLogTags:event tags:tags consumedKeys:consumedKeys];
    [self mapLogFields:event fields:fields consumedKeys:consumedKeys];

    [event enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
        if (![key isKindOfClass:NSString.class] || [consumedKeys containsObject:key] || [self isNull:value]) {
            return;
        }
        id normalized = [self lineProtocolValue:value];
        if (normalized) {
            fields[key] = normalized;
        }
    }];

    tags[FT_IS_WEBVIEW] = @(YES);
    FTWebViewLogEvent *result = [FTWebViewLogEvent new];
    result.content = [self stringValue:rawMessage];
    result.status = [self normalizedStatus:[self valueAtPath:@"status" inObject:event]];
    result.tags = [tags copy];
    result.fields = [fields copy];
    result.time = [self resolvedNanosecondTime:event[@"date"]];
    return result;
}

+ (void)removeRumLinkDataFromEvent:(FTWebViewLogEvent *)event {
    if (!event) {
        return;
    }
    NSArray<NSString *> *tagKeys = @[
        FT_APP_ID, FT_RUM_KEY_SESSION_ID, FT_RUM_KEY_SESSION_TYPE,
        @"session_is_forced", @"session_sampling", FT_KEY_VIEW_ID,
        @"view_referrer", @"view_url", @"view_host", @"view_path",
        @"view_name", @"view_path_group", @"view_path_name", FT_KEY_ACTION_ID
    ];
    NSArray<NSString *> *fieldKeys = @[
        @"application", @"session", @"view", @"action", @"user_action",
        @"view_url_query", FT_KEY_ACTION_ID, @"action_ids", @"view_in_foreground",
        @"session_has_replay"
    ];
    NSMutableDictionary *tags = [event.tags mutableCopy];
    NSMutableDictionary *fields = [event.fields mutableCopy];
    [tags removeObjectsForKeys:tagKeys];
    [fields removeObjectsForKeys:fieldKeys];
    event.tags = [tags copy];
    event.fields = [fields copy];
}

+ (void)replaceRumLinkDataInEvent:(FTWebViewLogEvent *)event
                    applicationId:(NSString *)applicationId
                         sessionId:(NSString *)sessionId {
    [self replaceRumLinkIdInEvent:event tagKey:FT_APP_ID fieldKey:@"application" value:applicationId];
    [self replaceRumLinkIdInEvent:event tagKey:FT_RUM_KEY_SESSION_ID fieldKey:@"session" value:sessionId];
}

+ (void)mapCommonTags:(NSDictionary *)event
                  tags:(NSMutableDictionary *)tags
          consumedKeys:(NSMutableSet<NSString *> *)consumedKeys {
    NSArray<NSArray<NSString *> *> *mappings = @[
        @[@"sdk_name", @"_gc.sdk_name"], @[@"sdk_version", @"_gc.sdk_version"],
        @[@"app_id", @"application.id"], @[@"env", @"env"],
        @[@"service", @"service"], @[@"version", @"version"],
        @[@"source", @"source"], @[@"userid", @"user.id"],
        @[@"user_email", @"user.email"], @[@"user_name", @"user.name"],
        @[@"session_id", @"session.id"], @[@"session_type", @"session.type"],
        @[@"session_is_forced", @"session.is_forced_session"],
        @[@"session_sampling", @"session.is_sampling"],
        @[@"is_signin", @"user.is_signin"], @[@"os", @"device.os"],
        @[@"os_version", @"device.os_version"],
        @[@"os_version_major", @"device.os_version_major"],
        @[@"browser", @"device.browser"],
        @[@"browser_version", @"device.browser_version"],
        @[@"browser_version_major", @"device.browser_version_major"],
        @[@"screen_size", @"device.screen_size"],
        @[@"network_type", @"device.network_type"],
        @[@"time_zone", @"device.time_zone"], @[@"device", @"device.device"],
        @[@"user_agent", @"device.user_agent"], @[@"view_id", @"view.id"],
        @[@"view_referrer", @"view.referrer"], @[@"view_url", @"view.url"],
        @[@"view_host", @"view.host"], @[@"view_path", @"view.path"],
        @[@"view_name", @"view.name"], @[@"view_path_group", @"view.path_group"],
        @[@"view_path_name", @"view.pathname"]
    ];
    for (NSArray<NSString *> *mapping in mappings) {
        [self addTagFromEvent:event tags:tags consumedKeys:consumedKeys target:mapping[0] path:mapping[1]];
    }
}

+ (void)mapCommonFields:(NSDictionary *)event
                  fields:(NSMutableDictionary *)fields
            consumedKeys:(NSMutableSet<NSString *> *)consumedKeys {
    NSArray<NSArray<NSString *> *> *mappings = @[
        @[@"view_url_query", @"view.url_query"], @[@"action_id", @"action.id"],
        @[@"action_ids", @"action.ids"], @[@"view_in_foreground", @"view.in_foreground"],
        @[@"display", @"display"], @[@"session_has_replay", @"session.has_replay"],
        @[@"is_login", @"user.is_login"], @[@"page_states", @"_gc.page_states"],
        @[@"session_sample_rate", @"_gc.configuration.session_sample_rate"],
        @[@"session_replay_sample_rate", @"_gc.configuration.session_replay_sample_rate"],
        @[@"session_on_error_sample_rate", @"_gc.configuration.session_on_error_sample_rate"],
        @[@"session_replay_on_error_sample_rate", @"_gc.configuration.session_replay_on_error_sample_rate"],
        @[@"drift", @"_gc.drift"]
    ];
    for (NSArray<NSString *> *mapping in mappings) {
        [self addFieldFromEvent:event fields:fields consumedKeys:consumedKeys target:mapping[0] path:mapping[1]];
    }
}

+ (void)mapLogTags:(NSDictionary *)event
               tags:(NSMutableDictionary *)tags
       consumedKeys:(NSMutableSet<NSString *> *)consumedKeys {
    NSArray<NSArray<NSString *> *> *mappings = @[
        @[@"error_source", @"error.source"], @[@"error_type", @"error.type"],
        @[@"error_resource_url", @"http.url"],
        @[@"error_resource_url_host", @"http.url_host"],
        @[@"error_resource_url_path", @"http.url_path"],
        @[@"error_resource_url_path_group", @"http.url_path_group"],
        @[@"error_resource_status", @"http.status_code"],
        @[@"error_resource_status_group", @"http.status_group"],
        @[@"error_resource_method", @"http.method"],
        @[@"action_id", @"user_action.id"], @[@"service", @"service"],
        @[@"status", @"status"]
    ];
    for (NSArray<NSString *> *mapping in mappings) {
        [self addTagFromEvent:event tags:tags consumedKeys:consumedKeys target:mapping[0] path:mapping[1]];
    }
}

+ (void)mapLogFields:(NSDictionary *)event
                fields:(NSMutableDictionary *)fields
          consumedKeys:(NSMutableSet<NSString *> *)consumedKeys {
    NSArray<NSArray<NSString *> *> *mappings = @[
        @[@"message", @"message"], @[@"error_message", @"error.message"],
        @[@"error_stack", @"error.stack"]
    ];
    for (NSArray<NSString *> *mapping in mappings) {
        [self addFieldFromEvent:event fields:fields consumedKeys:consumedKeys target:mapping[0] path:mapping[1]];
    }
}

+ (void)addTagFromEvent:(NSDictionary *)event
                    tags:(NSMutableDictionary *)tags
            consumedKeys:(NSMutableSet<NSString *> *)consumedKeys
                  target:(NSString *)target
                    path:(NSString *)path {
    [consumedKeys addObject:target];
    id value = [self valueAtPath:path inObject:event];
    if (![self isTruthyTagValue:value]) {
        return;
    }
    id normalized = [self lineProtocolValue:value];
    if (normalized) {
        tags[target] = normalized;
    }
}

+ (void)addFieldFromEvent:(NSDictionary *)event
                    fields:(NSMutableDictionary *)fields
              consumedKeys:(NSMutableSet<NSString *> *)consumedKeys
                    target:(NSString *)target
                      path:(NSString *)path {
    [consumedKeys addObject:target];
    id value = [self valueAtPath:path inObject:event];
    if ([self isNull:value]) {
        return;
    }
    id normalized = [self lineProtocolValue:value];
    if (normalized) {
        fields[target] = normalized;
    }
}

+ (nullable id)valueAtPath:(NSString *)path inObject:(NSDictionary *)object {
    id current = object;
    for (NSString *component in [path componentsSeparatedByString:@"."]) {
        if (![current isKindOfClass:NSDictionary.class]) {
            return nil;
        }
        current = current[component];
        if ([self isNull:current]) {
            return nil;
        }
    }
    return current;
}

+ (BOOL)isTruthyTagValue:(id)value {
    if ([self isNull:value]) {
        return NO;
    }
    if ([value isKindOfClass:NSNumber.class]) {
        if (CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID()) {
            return [value boolValue];
        }
        return YES;
    }
    if ([value isKindOfClass:NSString.class]) {
        return [value length] > 0;
    }
    return YES;
}

+ (BOOL)isNull:(id)value {
    return value == nil || value == (id)kCFNull || [value isKindOfClass:NSNull.class];
}

+ (nullable id)lineProtocolValue:(id)value {
    if ([value isKindOfClass:NSDictionary.class] || [value isKindOfClass:NSArray.class]) {
        return [FTJSONUtil convertToJsonDataWithObject:value];
    }
    return value;
}

+ (NSString *)stringValue:(id)value {
    if ([value isKindOfClass:NSDictionary.class] || [value isKindOfClass:NSArray.class]) {
        return [FTJSONUtil convertToJsonDataWithObject:value] ?: [value description];
    }
    if ([value isKindOfClass:NSNumber.class] && CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID()) {
        return [value boolValue] ? @"true" : @"false";
    }
    return [value description];
}

+ (NSString *)normalizedStatus:(id)value {
    if ([self isNull:value]) {
        return @"info";
    }
    NSString *status = [[self stringValue:value] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (status.length == 0) {
        return @"info";
    }
    return [status isEqualToString:@"warn"] ? @"warning" : status;
}

+ (long long)resolvedNanosecondTime:(id)value {
    if ([value isKindOfClass:NSNumber.class]
        && CFGetTypeID((__bridge CFTypeRef)value) != CFBooleanGetTypeID()) {
        double millisecondsDouble = [value doubleValue];
        double maxMilliseconds = (double)LLONG_MAX / (double)FTNanosecondsPerMillisecond;
        if (isfinite(millisecondsDouble) && millisecondsDouble > 0 && millisecondsDouble <= maxMilliseconds) {
            long long milliseconds = [value longLongValue];
            if (milliseconds > 0 && milliseconds <= LLONG_MAX / FTNanosecondsPerMillisecond) {
                return milliseconds * FTNanosecondsPerMillisecond;
            }
        }
    }
    return [NSDate ft_currentNanosecondTimeStamp];
}

+ (void)replaceRumLinkIdInEvent:(FTWebViewLogEvent *)event
                          tagKey:(NSString *)tagKey
                        fieldKey:(NSString *)fieldKey
                           value:(NSString *)value {
    if (!event || value.length == 0) {
        return;
    }
    NSMutableDictionary *tags = [event.tags mutableCopy];
    tags[tagKey] = value;
    event.tags = [tags copy];

    id rawObject = event.fields[fieldKey];
    if (!rawObject) {
        return;
    }
    NSDictionary *object = nil;
    if ([rawObject isKindOfClass:NSDictionary.class]) {
        object = rawObject;
    } else if ([rawObject isKindOfClass:NSString.class]) {
        object = [FTJSONUtil dictionaryWithJsonString:rawObject];
    }
    if (!object) {
        return;
    }
    NSMutableDictionary *replacement = [object mutableCopy];
    replacement[@"id"] = value;
    NSString *json = [FTJSONUtil convertToJsonData:replacement];
    if (json) {
        NSMutableDictionary *fields = [event.fields mutableCopy];
        fields[fieldKey] = json;
        event.fields = [fields copy];
    }
}

@end
