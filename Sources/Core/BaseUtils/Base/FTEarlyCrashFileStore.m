//
//  FTEarlyCrashFileStore.m
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

#import <Foundation/Foundation.h>
#import "FTEarlyCrash.h"
#import "FTInnerLog.h"
#import "FTSDKCompat.h"

NSString *ft_crashInstallPath(void) {
    NSArray *directories = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    if ([directories count] == 0) {
        FTInnerLogError(@"Could not locate cache directory path.");
        return nil;
    }
    NSString *cachePath = [directories objectAtIndex:0];
    if ([cachePath length] == 0) {
        FTInnerLogError(@"Could not locate cache directory path.");
        return nil;
    }
    NSString *bundle = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"] ?: @"Unknown";
    NSString *pathEnd = [@"FTCrash" stringByAppendingPathComponent:[bundle stringByReplacingOccurrencesOfString:@"/" withString:@"-"]];
    return [cachePath stringByAppendingPathComponent:pathEnd];
}

static NSString *earlyCrashMarkerPath(void) {
    if ([[NSBundle mainBundle].bundlePath.pathExtension isEqualToString:@"appex"]) return nil;
    return [[ft_crashInstallPath() stringByAppendingPathComponent:@"Data"]
            stringByAppendingPathComponent:@"EarlyCrash.marker"];
}

void ft_earlyCrashLoadHistory(void) {
#if TARGET_OS_IOS && !TARGET_OS_MACCATALYST
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        dispatch_async(ft_earlyCrashPreparationQueue(), ^{
            @autoreleasepool {
                @try {
                    ft_earlyCrashRestoreHistory(earlyCrashMarkerPath().fileSystemRepresentation);
                } @catch (__unused NSException *exception) {
                    ft_earlyCrashRestoreHistory(NULL);
                }
            }
        });
    });
#endif
}

void ft_earlyCrashEnableRecording(void) {
#if TARGET_OS_IOS && !TARGET_OS_MACCATALYST
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        dispatch_async(ft_earlyCrashPreparationQueue(), ^{
            @autoreleasepool {
                @try {
                    NSString *path = earlyCrashMarkerPath();
                    ft_earlyCrashRestoreHistory(path.fileSystemRepresentation);
                    NSString *directory = path.stringByDeletingLastPathComponent;
                    BOOL created = directory && [[NSFileManager defaultManager]
                        createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
                    ft_earlyCrashPrepareRecording(created ? path.fileSystemRepresentation : NULL);
                } @catch (__unused NSException *exception) {
                    ft_earlyCrashRestoreHistory(NULL);
                    ft_earlyCrashPrepareRecording(NULL);
                }
            }
        });
    });
#endif
}
