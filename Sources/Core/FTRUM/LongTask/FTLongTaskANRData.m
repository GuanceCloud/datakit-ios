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

static NSString *const kFTLongTaskSDKDirName = @"com.ft.sdk";
static NSString *const kFTLongTaskANRDataVersion = @"2.0.0";
static NSString *const kFTLongTaskANRDataBoundary = @"\n___boundary.info.date___\n";
static void *FTLongTaskANRDataStoreQueueTag = &FTLongTaskANRDataStoreQueueTag;

long long const FTLongTaskANRDataThresholdNs = 3LL * NSEC_PER_SEC;
long long const FTLongTaskANRDataUpdateIntervalNs = 1LL * NSEC_PER_SEC;

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
    [dict setValue:[self.errorContextModel toDictionary] forKey:@"errorContextModel"];
    return dict;
}

@end

@interface FTLongTaskANRDataStore ()
@property (nonatomic, strong) dispatch_queue_t queue;
@end

@implementation FTLongTaskANRDataStore

@synthesize dataStorePath = _dataStorePath;

- (instancetype)init {
    self = [super init];
    if (self) {
        _queue = dispatch_queue_create("com.ft.longtask.anr_data", DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(_queue, FTLongTaskANRDataStoreQueueTag, FTLongTaskANRDataStoreQueueTag, NULL);
    }
    return self;
}

- (NSFileHandle *)fileHandle {
    if (!_fileHandle) {
        _fileHandle = [NSFileHandle fileHandleForUpdatingAtPath:[self createFile]];
        @try {
            if (@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)) {
                __autoreleasing NSError *error = nil;
                [_fileHandle seekToEndReturningOffset:nil error:&error];
                if (error) {
                    FTInnerLogError(@"[LongTask] error %@", error.description);
                }
            } else {
                [_fileHandle seekToEndOfFile];
            }
        } @catch (NSException *exception) {
            FTInnerLogError(@"[LongTask] exception %@", exception);
        }
    }
    return _fileHandle;
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

- (void)setDataStorePath:(NSString *)dataStorePath {
    if (_dataStorePath != dataStorePath && ![_dataStorePath isEqualToString:dataStorePath]) {
        _fileHandle = nil;
    }
    _dataStorePath = [dataStorePath copy];
}

- (void)appendData:(NSData *)data {
    __weak __typeof(self) weakSelf = self;
    [self performAsync:^{
        @try {
            __strong __typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            [strongSelf writeData:data];
        } @catch (NSException *exception) {
            FTInnerLogError(@"[LongTask] exception %@", exception);
        }
    }];
}

- (void)deleteFile {
    __weak __typeof(self) weakSelf = self;
    dispatch_block_t block = ^{
        @try {
            __strong __typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            [strongSelf deleteFileUnsafe];
        } @catch (NSException *exception) {
            FTInnerLogError(@"[LongTask] exception %@", exception);
        }
    };
    [self performSync:block];
}

- (void)writeANRData:(FTLongTaskANRData *)anrData updateTimeNs:(long long)updateTimeNs resetFile:(BOOL)resetFile {
    if (!anrData) {
        return;
    }
    __weak __typeof(self) weakSelf = self;
    [self performAsync:^{
        @try {
            __strong __typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            if (resetFile) {
                [strongSelf deleteFileUnsafe];
            }
            NSDictionary *dict = [anrData convertToDictionary];
            NSString *jsonString = [FTJSONUtil convertToJsonDataWithObject:dict];
            if (!jsonString) {
                FTInnerLogError(@"[LongTask] longTask ANR data convert to Json Data Error");
                return;
            }
            NSString *payload = [NSString stringWithFormat:@"%@%@%@%@%lld\n", kFTLongTaskANRDataVersion, kFTLongTaskANRDataBoundary, jsonString, kFTLongTaskANRDataBoundary, updateTimeNs];
            NSData *data = [payload dataUsingEncoding:NSUTF8StringEncoding];
            [strongSelf writeData:data];
        } @catch (NSException *exception) {
            FTInnerLogError(@"[LongTask] exception %@", exception);
        }
    }];
}

- (void)appendUpdateTimeNs:(long long)updateTimeNs {
    NSString *lastDate = [NSString stringWithFormat:@"%lld\n", updateTimeNs];
    [self appendData:[lastDate dataUsingEncoding:NSUTF8StringEncoding]];
}

- (FTLongTaskANRData *)readANRData {
    __block FTLongTaskANRData *anrData = nil;
    [self performSync:^{
        @try {
            NSString *content = [NSString stringWithContentsOfFile:self.dataStorePath encoding:NSUTF8StringEncoding error:nil];
            if (content.length == 0) {
                return;
            }
            NSArray *datas = [content componentsSeparatedByString:kFTLongTaskANRDataBoundary];
            if (datas.count != 3) {
                return;
            }
            if (![datas[0] isEqualToString:kFTLongTaskANRDataVersion]) {
                return;
            }
            NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:datas[1]];
            if (!dict) {
                return;
            }
            NSArray *updateTimes = [datas[2] componentsSeparatedByString:@"\n"];
            __block long long lastTime = 0;
            [updateTimes enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSString *obj, NSUInteger idx, BOOL *stop) {
                if (obj.length > 0) {
                    lastTime = [obj longLongValue];
                    *stop = YES;
                }
            }];
            anrData = [[FTLongTaskANRData alloc] initWithDictionary:dict];
            anrData.lastUpdateTimeNs = lastTime;
        } @catch (NSException *exception) {
            FTInnerLogError(@"[LongTask] exception %@", exception);
        }
    }];
    return anrData;
}

- (void)performAsync:(dispatch_block_t)block {
    dispatch_async(self.queue, block);
}

- (void)performSync:(dispatch_block_t)block {
    if (dispatch_get_specific(FTLongTaskANRDataStoreQueueTag)) {
        block();
    } else {
        dispatch_sync(self.queue, block);
    }
}

- (NSString *)createFile {
    @try {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if ([fileManager fileExistsAtPath:self.dataStorePath]) {
            return self.dataStorePath;
        }
        BOOL isSuccess = [fileManager createFileAtPath:self.dataStorePath contents:nil attributes:nil];
        if (isSuccess) {
            return self.dataStorePath;
        }
    } @catch (NSException *exception) {
        FTInnerLogError(@"[LongTask] exception %@", exception);
    }
    return nil;
}

- (void)writeData:(NSData *)data {
    NSError *error = nil;
    if (@available(macOS 10.15, iOS 13.0, tvOS 13.0, *)) {
        [self.fileHandle writeData:data error:&error];
        if (error) {
            FTInnerLogError(@"[LongTask] writeData error %@", error.description);
        }
    } else {
        [self.fileHandle writeData:data];
    }
}

- (void)deleteFileUnsafe {
    NSError *error = nil;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL fileExists = [fileManager fileExistsAtPath:self.dataStorePath];
    if (fileExists) {
        [fileManager removeItemAtPath:self.dataStorePath error:&error];
        if (error) {
            FTInnerLogError(@"[LongTask] delete file：%@ fail. reason: %@", self.dataStorePath, error.description);
        }
    }
    self.fileHandle = nil;
}

- (NSSearchPathDirectory)supportedDirectory {
#if TARGET_OS_TV
    return NSCachesDirectory;
#else
    return NSApplicationSupportDirectory;
#endif
}

- (void)dealloc {
    if (_fileHandle) {
        @try {
            if (@available(macOS 10.15, iOS 13.0, tvOS 13.0, *)) {
                NSError *error = nil;
                [_fileHandle synchronizeAndReturnError:&error];
                if (error) {
                    FTInnerLogError(@"[FTLog][FTFileLogger] Failed to synchronize file: %@", error.description);
                }
            } else {
                [_fileHandle synchronizeFile];
            }
        } @catch (NSException *exception) {
            FTInnerLogError(@"[FTLog][FTFileLogger] Failed to synchronize file: %@", exception);
        }
    }
}

@end
