//
//  FTIssueDataProvider.m
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

#import "FTIssueFieldEnricher.h"
#import "FTInnerLog.h"
#import <CoreFoundation/CoreFoundation.h>
#import <math.h>
#import <string.h>

static NSUInteger const FTIssueMaximumScannedEntryCount = 50;
static NSUInteger const FTIssueMaximumKeyBytes = 100;
static NSUInteger const FTIssueMaximumStringBytes = 4096;
static NSUInteger const FTIssueMaximumTotalBytes = 25 * 1024;
static NSTimeInterval const FTIssueSlowProviderThreshold = 0.050;

@implementation FTIssueInfo

- (instancetype)initWithCategory:(FTIssueCategory)category
                       errorType:(NSString *)errorType
                         message:(nullable NSString *)message
                           stack:(NSString *)stack
           occurredAtNanoseconds:(long long)occurredAtNanoseconds
                        appState:(NSString *)appState
                      threadName:(nullable NSString *)threadName
                      historical:(BOOL)historical {
    self = [super init];
    if (self) {
        _category = category;
        _errorType = [errorType copy];
        _message = [message copy];
        _stack = [stack copy];
        _occurredAtNanoseconds = occurredAtNanoseconds;
        _appState = [appState copy];
        _threadName = [threadName copy];
        _historical = historical;
    }
    return self;
}

@end

@interface FTIssueFieldEnricher ()
@property (nonatomic, copy, nullable) FTIssueDataProvider provider;
@end

@implementation FTIssueFieldEnricher

- (instancetype)initWithProvider:(nullable FTIssueDataProvider)provider {
    self = [super init];
    if (self) {
        _provider = [provider copy];
    }
    return self;
}

- (NSDictionary<NSString *,id> *)fieldsForIssue:(FTIssueInfo *)issue
                                   reservedKeys:(nullable NSSet<NSString *> *)reservedKeys {
    FTIssueDataProvider provider = [self.provider copy];
    if (!provider || !issue) {
        return @{};
    }

    NSDictionary *suppliedFields = nil;
    NSTimeInterval startTime = NSProcessInfo.processInfo.systemUptime;
    @try {
        id result = provider(issue);
        if ([result isKindOfClass:NSDictionary.class]) {
            suppliedFields = result;
        }
    } @catch (NSException *exception) {
        FTInnerLogWarning(@"[RUM][IssueProvider] Provider raised an exception for category %lu.",
                          (unsigned long)issue.category);
    }
    NSTimeInterval elapsed = NSProcessInfo.processInfo.systemUptime - startTime;
    if (elapsed > FTIssueSlowProviderThreshold) {
        FTInnerLogWarning(@"[RUM][IssueProvider] Slow Provider for category %lu: %.2f ms.",
                          (unsigned long)issue.category,
                          elapsed * 1000.0);
    }
    if (!suppliedFields) {
        return @{};
    }

    NSEnumerator *keyEnumerator = nil;
    @try {
        keyEnumerator = suppliedFields.keyEnumerator;
    } @catch (NSException *exception) {
        FTInnerLogWarning(@"[RUM][IssueProvider] Unable to traverse Provider result.");
        return @{};
    }

    NSMutableDictionary<NSString *, id> *acceptedFields = [NSMutableDictionary dictionary];
    NSUInteger estimatedBytes = 0;
    for (NSUInteger scannedEntries = 0;
         scannedEntries < FTIssueMaximumScannedEntryCount;
         scannedEntries++) {
        id rawKey = nil;
        @try {
            rawKey = [keyEnumerator nextObject];
        } @catch (NSException *exception) {
            FTInnerLogWarning(@"[RUM][IssueProvider] Unable to traverse Provider result.");
            return @{};
        }
        if (!rawKey) {
            break;
        }
        if (![rawKey isKindOfClass:NSString.class]) {
            continue;
        }

        @try {
            NSString *key = [rawKey copy];
            NSUInteger keyBytes = [key lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
            if (key.length == 0 || keyBytes == 0 || keyBytes > FTIssueMaximumKeyBytes ||
                [self isReservedKey:key additionalReservedKeys:reservedKeys]) {
                continue;
            }

            id value = [suppliedFields objectForKey:rawKey];
            id copiedValue = nil;
            NSUInteger valueBytes = 0;
            if ([value isKindOfClass:NSString.class]) {
                NSString *stringValue = [value copy];
                if (![stringValue canBeConvertedToEncoding:NSUTF8StringEncoding]) {
                    continue;
                }
                valueBytes = [stringValue lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
                if (valueBytes > FTIssueMaximumStringBytes) {
                    continue;
                }
                copiedValue = stringValue;
            } else if ([value isKindOfClass:NSNumber.class]) {
                NSNumber *numberValue = value;
                BOOL isBoolean = NO;
                if (![self isSupportedNumber:numberValue booleanValue:&isBoolean]) {
                    continue;
                }
                valueBytes = isBoolean ? 1 : 8;
                copiedValue = [numberValue copy];
            } else {
                continue;
            }

            NSUInteger entryBytes = keyBytes + valueBytes;
            if (entryBytes > FTIssueMaximumTotalBytes ||
                estimatedBytes > FTIssueMaximumTotalBytes - entryBytes) {
                continue;
            }
            acceptedFields[key] = copiedValue;
            estimatedBytes += entryBytes;
        } @catch (NSException *exception) {
            continue;
        }
    }
    return [acceptedFields copy];
}

- (BOOL)isSupportedNumber:(NSNumber *)number booleanValue:(BOOL *)booleanValue {
    BOOL isBoolean = CFGetTypeID((__bridge CFTypeRef)number) == CFBooleanGetTypeID();
    if (booleanValue) {
        *booleanValue = isBoolean;
    }
    if (isBoolean) {
        return YES;
    }

    const char *type = number.objCType;
    if (!type || strlen(type) != 1) {
        return NO;
    }
    switch (type[0]) {
        case 'c':
        case 's':
        case 'i':
        case 'l':
        case 'q':
        case 'C':
        case 'S':
        case 'I':
        case 'L':
        case 'Q':
            return YES;
        case 'f':
        case 'd':
            return isfinite(number.doubleValue);
        default:
            return NO;
    }
}

- (BOOL)isReservedKey:(NSString *)key additionalReservedKeys:(nullable NSSet<NSString *> *)reservedKeys {
    if ([reservedKeys containsObject:key]) {
        return YES;
    }
    return [key hasPrefix:@"error."] || [key hasPrefix:@"error_"];
}

@end
