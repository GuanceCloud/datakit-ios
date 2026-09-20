//
//  FTLog.h
//  FTMobileAgent
//
//  Created by hulilei on 2020/5/19.
//  Copyright 2021 Shanghai Guance Information Technology Co., Ltd.
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

NS_ASSUME_NONNULL_BEGIN


/// SDK internal debug logs
@interface FTLog : NSObject

/// Singleton
+ (instancetype)sharedInstance;

/// Write debug logs to the default file.
/// Documents/FTLogs/FTLog.log
- (void)registerInnerLogCacheToDefaultPath;

/// Write debug logs to file. If logsDirectory is not specified, a folder named 'FTLogs' will be created in the application's Documents. If fileNamePrefix is not specified, the log file prefix is 'FTLog'
/// - Parameters:
///   - logsDirectory: Folder to store log files
///   - fileNamePrefix: Log file name prefix
- (void)registerInnerLogCacheToLogsDirectory:(nullable NSString *)logsDirectory fileNamePrefix:(nullable NSString *)fileNamePrefix;


/// Write debug logs to the specified file.
/// - Parameter filePath: Log file write path
///
/// Example:
/// ```
/// NSString *baseDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
/// NSString *logsDirectory = [baseDir stringByAppendingPathComponent:@"ExampleLogs"];
/// NSString *filePath = [logsDirectory stringByAppendingPathComponent:@"ExampleName.log"];
/// [[FTLog sharedInstance] registerInnerLogCacheToLogsFilePath:filePath];
/// ```
- (void)registerInnerLogCacheToLogsFilePath:(NSString *)filePath;
@end

NS_ASSUME_NONNULL_END
