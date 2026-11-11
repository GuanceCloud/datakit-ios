//
//  FTLongTaskANRData.m
//  FTMobileSDK
//
//  Created by hulilei on 2026/6/26.
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

#import "FTLongTaskANRData.h"
#import "FTJSONUtil.h"
#import "FTInnerLog.h"
#import "FTInternalConstants.h"
#import <stdatomic.h>

static NSString *const kFTLongTaskSDKDirName = @"com.ft.sdk";
static NSString *const kFTLongTaskANRDataVersion = @"2.0.0";
static NSString *const kFTLongTaskANRDataBoundary = @"\n___boundary.info.date___\n";
static void *FTLongTaskANRDataStoreQueueTag = &FTLongTaskANRDataStoreQueueTag;

long long const FTLongTaskANRDataThresholdNs = 3LL * NSEC_PER_SEC;
long long const FTLongTaskANRDataUpdateIntervalNs = 1LL * NSEC_PER_SEC;

static BOOL FTIsValidStoredNanoseconds(id value, long long minimum) {
    if (![value isKindOfClass:NSNumber.class] ||
        CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID()) return NO;
    long long nanoseconds = [value longLongValue];
    // The exact round trip rejects fractions and signed 64-bit overflow without double rounding.
    return nanoseconds >= minimum && [value compare:@(nanoseconds)] == NSOrderedSame;
}

@implementation FTLongTaskANRData

- (instancetype)initWithStartTimeNs:(long long)startTimeNs
                         durationNs:(long long)durationNs
                 mainThreadBacktrace:(NSString *)mainThreadBacktrace
                 allThreadsBacktrace:(NSString *)allThreadsBacktrace
                   errorContextModel:(FTFatalErrorContextModel *)errorContextModel {
    self = [super init];
    if (self) {
        _startTimeNs = startTimeNs;
        _durationNs = durationNs;
        _mainThreadBacktrace = [mainThreadBacktrace copy];
        _allThreadsBacktrace = [allThreadsBacktrace copy];
        _errorContextModel = errorContextModel;
    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)dict {
    if (![dict isKindOfClass:NSDictionary.class]) {
        return nil;
    }
    self = [super init];
    if (self) {
        _startTimeNs = [dict[@"startDate"] longLongValue];
        _durationNs = [dict[@"duration"] longLongValue];
        if ([dict[@"effectiveDuration"] isKindOfClass:NSNumber.class]) {
            _usesEffectiveDuration = YES;
            _durationNs = [dict[@"effectiveDuration"] longLongValue];
            _endTimeNs = [dict[@"endDate"] longLongValue];
        }
        _mainThreadBacktrace = [dict[@"mainThreadBacktrace"] copy];
        _allThreadsBacktrace = [dict[@"allThreadsBacktrace"] copy];
        NSDictionary *contextDict = dict[@"errorContextModel"];
        if ([contextDict isKindOfClass:NSDictionary.class]) {
            _errorContextModel = [[FTFatalErrorContextModel alloc] initWithDict:contextDict];
        }
    }
    return self;
}

- (NSDictionary *)convertToDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setValue:@(self.durationNs > FT_ANR_THRESHOLD_NS) forKey:@"isANR"];
    [dict setValue:@(self.startTimeNs) forKey:@"startDate"];
    [dict setValue:self.mainThreadBacktrace forKey:@"mainThreadBacktrace"];
    [dict setValue:self.allThreadsBacktrace forKey:@"allThreadsBacktrace"];
    [dict setValue:@(self.durationNs) forKey:@"duration"];
    if (self.usesEffectiveDuration) {
        dict[@"effectiveDuration"] = @(self.durationNs);
        dict[@"endDate"] = @(self.endTimeNs);
    }
    [dict setValue:[self.errorContextModel toDictionary] forKey:@"errorContextModel"];
    return dict;
}

@end

@interface FTLongTaskANRDataStore () {
    atomic_bool _closed;
    NSMutableDictionary *_baseSnapshot; // File-queue owned; retained for retry if an atomic write fails.
    BOOL _baseSnapshotWritten;
}
@property (nonatomic, strong) dispatch_queue_t queue;
@end

@implementation FTLongTaskANRDataStore

@synthesize dataStorePath = _dataStorePath;

- (instancetype)init {
    self = [super init];
    if (self) {
        // Every SDK instance uses the same file. One queue keeps old cleanup ahead
        // of recovery/writes from a newly initialized SDK.
        static dispatch_queue_t fileQueue;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            fileQueue = dispatch_queue_create("com.ft.longtask.anr_data", DISPATCH_QUEUE_SERIAL);
            dispatch_queue_set_specific(fileQueue, FTLongTaskANRDataStoreQueueTag, FTLongTaskANRDataStoreQueueTag, NULL);
        });
        _queue = fileQueue;
        atomic_init(&_closed, false);
    }
    return self;
}

- (BOOL)isClosed {
    return atomic_load(&_closed);
}

- (void)shutDown {
    if (atomic_exchange(&_closed, true)) return;
    // Retain the store until its queued deletion finishes, even if the manager is released.
    dispatch_async(self.queue, ^{
        @try {
            [self deleteFileUnsafe];
        } @catch (NSException *exception) {
            FTInnerLogError(@"[LongTask] exception %@", exception);
        }
    });
}

- (NSString *)dataStorePath {
    if (!_dataStorePath) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSURL *appSupportDir = [[fileManager URLsForDirectory:[self supportedDirectory] inDomains:NSUserDomainMask] firstObject];
        NSURL *sdkDirectory = [appSupportDir URLByAppendingPathComponent:kFTLongTaskSDKDirName];
        if (![fileManager fileExistsAtPath:sdkDirectory.path]) {
            [fileManager createDirectoryAtURL:sdkDirectory withIntermediateDirectories:YES attributes:nil error:nil];
        }

        NSURL *fileURL = [sdkDirectory URLByAppendingPathComponent:@"longtask.log"];
#if TARGET_OS_IOS
        NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
#elif TARGET_OS_TV
        NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
#else
        NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
#endif
        NSString *oldPath = [docPath stringByAppendingPathComponent:@"FTLongTask.txt"];
        if ([fileManager fileExistsAtPath:oldPath]) {
            NSError *moveError = nil;
            [fileManager removeItemAtPath:oldPath error:&moveError];
        }
        _dataStorePath = fileURL.path;
    }
    return _dataStorePath;
}

- (void)deleteFile {
    if (self.isClosed) return;
    __weak __typeof(self) weakSelf = self;
    dispatch_block_t block = ^{
        @try {
            __strong __typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf || strongSelf.isClosed) return;
            [strongSelf deleteFileUnsafe];
        } @catch (NSException *exception) {
            FTInnerLogError(@"[LongTask] exception %@", exception);
        }
    };
    [self performSync:block];
}

- (void)writeANRData:(FTLongTaskANRData *)anrData {
    if (!anrData || self.isClosed) return;
    NSDictionary *snapshot = [anrData convertToDictionary];
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.queue, ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || self.isClosed) return;
        @try {
            self->_baseSnapshot = [snapshot mutableCopy];
            [self writeBaseSnapshotUnsafe];
        } @catch (NSException *exception) {
            FTInnerLogError(@"[LongTask] exception %@", exception);
        }
    });
}

- (void)writeBaseSnapshotUnsafe {
    _baseSnapshotWritten = NO;
    NSString *json = [FTJSONUtil convertToJsonDataWithObject:_baseSnapshot];
    if (!json) return;
    NSString *payload = [NSString stringWithFormat:@"3.0.0%@%@%@", kFTLongTaskANRDataBoundary, json, kFTLongTaskANRDataBoundary];
    NSError *error = nil;
    NSData *data = [payload dataUsingEncoding:NSUTF8StringEncoding];
    _baseSnapshotWritten = [data writeToFile:self.dataStorePath options:NSDataWritingAtomic error:&error];
    if (!_baseSnapshotWritten) FTInnerLogError(@"[LongTask] snapshot write failed: %@", error);
}

- (void)appendTimingWithStartTimeNs:(long long)startTimeNs durationNs:(long long)durationNs endTimeNs:(long long)endTimeNs {
    if (self.isClosed || startTimeNs <= 0 || durationNs < 0 || endTimeNs < startTimeNs) return;
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.queue, ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || self.isClosed || [self->_baseSnapshot[@"startDate"] longLongValue] != startTimeNs ||
            durationNs < [self->_baseSnapshot[@"effectiveDuration"] longLongValue]) return;
        @try {
            self->_baseSnapshot[@"effectiveDuration"] = @(durationNs);
            self->_baseSnapshot[@"duration"] = @(durationNs);
            self->_baseSnapshot[@"endDate"] = @(endTimeNs);
            self->_baseSnapshot[@"isANR"] = @(durationNs > FT_ANR_THRESHOLD_NS);
            if (!self->_baseSnapshotWritten) {
                // Retry a failed full write before this incident can receive timing-only records.
                [self writeBaseSnapshotUnsafe];
                return;
            }
            NSString *json = [FTJSONUtil convertToJsonDataWithObject:@{
                @"effectiveDuration": @(durationNs), @"endDate": @(endTimeNs)
            }];
            if (!json) return;
            // A leading newline isolates any torn previous append; the trailing newline commits this pair.
            NSData *record = [[NSString stringWithFormat:@"\n%@\n", json] dataUsingEncoding:NSUTF8StringEncoding];
            NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:self.dataStorePath];
            if (!handle) {
                [self writeBaseSnapshotUnsafe];
                return;
            }
            @try {
                [handle seekToEndOfFile];
                [handle writeData:record];
            } @finally {
                [handle closeFile];
            }
        } @catch (NSException *exception) {
            FTInnerLogError(@"[LongTask] timing append exception %@", exception);
        }
    });
}

- (FTLongTaskANRData *)readANRData {
    __block FTLongTaskANRData *anrData = nil;
    [self performSync:^{
        if (self.isClosed) return;
        @try {
            NSString *content = [NSString stringWithContentsOfFile:self.dataStorePath encoding:NSUTF8StringEncoding error:nil];
            if (content.length == 0) {
                return;
            }
            NSArray *datas = [content componentsSeparatedByString:kFTLongTaskANRDataBoundary];
            if (datas.count != 3) {
                return;
            }
            BOOL effective = [datas[0] isEqualToString:@"3.0.0"];
            if (!effective && ![datas[0] isEqualToString:kFTLongTaskANRDataVersion]) {
                return;
            }
            NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:datas[1]];
            if (!dict) return;
            if (effective) {
                NSNumber *startDate = dict[@"startDate"];
                if (!FTIsValidStoredNanoseconds(startDate, 1) ||
                    !FTIsValidStoredNanoseconds(dict[@"effectiveDuration"], 0) ||
                    !FTIsValidStoredNanoseconds(dict[@"endDate"], startDate.longLongValue)) return;
            }
            anrData = [[FTLongTaskANRData alloc] initWithDictionary:dict];
            NSArray<NSString *> *updateTimes = [datas[2] componentsSeparatedByString:@"\n"];
            if (effective) {
                // The last component lacks a terminating newline and may be a torn write.
                for (NSUInteger index = 0; index + 1 < updateTimes.count; index++) {
                    if (updateTimes[index].length == 0) continue;
                    NSDictionary *timing = [FTJSONUtil dictionaryWithJsonString:updateTimes[index]];
                    if (!FTIsValidStoredNanoseconds(timing[@"effectiveDuration"], anrData.durationNs) ||
                        !FTIsValidStoredNanoseconds(timing[@"endDate"], anrData.startTimeNs)) continue;
                    anrData.durationNs = [timing[@"effectiveDuration"] longLongValue];
                    anrData.endTimeNs = [timing[@"endDate"] longLongValue];
                }
                anrData.lastUpdateTimeNs = anrData.endTimeNs;
            } else {
                // Legacy v2 retains its epoch-timestamp trailer semantics.
                [updateTimes enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSString *obj, NSUInteger idx, BOOL *stop) {
                    if (obj.length > 0) {
                        anrData.lastUpdateTimeNs = [obj longLongValue];
                        *stop = YES;
                    }
                }];
            }
        } @catch (NSException *exception) {
            FTInnerLogError(@"[LongTask] exception %@", exception);
        }
    }];
    return anrData;
}

- (void)performSync:(dispatch_block_t)block {
    if (dispatch_get_specific(FTLongTaskANRDataStoreQueueTag)) {
        block();
    } else {
        dispatch_sync(self.queue, block);
    }
}

- (void)deleteFileUnsafe {
    _baseSnapshot = nil;
    _baseSnapshotWritten = NO;
    NSError *error = nil;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL fileExists = [fileManager fileExistsAtPath:self.dataStorePath];
    if (fileExists) {
        [fileManager removeItemAtPath:self.dataStorePath error:&error];
        if (error) {
            FTInnerLogError(@"[LongTask] delete file: %@ fail. reason: %@", self.dataStorePath, error.description);
        }
    }
}

- (NSSearchPathDirectory)supportedDirectory {
#if TARGET_OS_TV
    return NSCachesDirectory;
#else
    return NSApplicationSupportDirectory;
#endif
}


@end
