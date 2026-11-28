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
NS_ASSUME_NONNULL_BEGIN
/// Immutable after passing to the manager; configuration is copied.
@interface FTDiagnosticsConfig : NSObject <NSCopying>
@property uint64_t sessionBytes; // Default 20 MiB; minimum 128 KiB.
@property uint64_t totalBytes; // Default 100 MiB; >= sessionBytes.
@property NSTimeInterval retentionSeconds; // Default 7 days.
@end
/// Local-only optional component. Call management methods off the UI thread.
/// The directory must be private, dedicated to diagnostics and unique per process role.
@interface FTDiagnostics : NSObject
- (nullable instancetype)initWithDirectory:(NSURL *)directory config:(FTDiagnosticsConfig *)config error:(NSError **)error;
- (nullable NSString *)start:(NSError **)error;
- (nullable NSDictionary *)stop:(NSError **)error;
- (NSDictionary *)status;
- (nullable NSArray<NSDictionary *> *)sessions:(NSError **)error;
- (nullable NSDictionary *)summary:(NSString *)sessionID error:(NSError **)error;
- (nullable NSArray<NSDictionary *> *)records:(NSString *)sessionID offset:(NSUInteger)offset limit:(NSUInteger)limit error:(NSError **)error;
/// Export copies summary.json and events.jsonl into a new caller-owned directory.
- (BOOL)exportSession:(NSString *)sessionID toDirectory:(NSURL *)destination error:(NSError **)error;
- (BOOL)deleteSession:(NSString *)sessionID error:(NSError **)error;
- (BOOL)cleanExpired:(NSError **)error;
- (void)close;
@end
NS_ASSUME_NONNULL_END
