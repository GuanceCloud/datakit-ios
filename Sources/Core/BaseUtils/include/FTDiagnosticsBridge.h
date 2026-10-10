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
/// Internal SDK observation boundary. Do not register application callbacks here.
typedef void (^FTDiagnosticsSink)(NSDictionary<NSString *, id> *event);
@interface FTDiagnosticsAttempt : NSObject
- (void)finishWithStatus:(NSInteger)status requestBytes:(int64_t)tx responseBytes:(int64_t)rx source:(NSString *)source;
- (void)finishWithStatus:(NSInteger)status transportError:(BOOL)failed requestBytes:(int64_t)tx responseBytes:(int64_t)rx source:(NSString *)source;
@end
@interface FTDiagnosticsBridge : NSObject
+ (BOOL)enabled;
+ (BOOL)install:(FTDiagnosticsSink)sink;
+ (void)uninstall:(FTDiagnosticsSink)sink;
+ (NSString *)channel:(nullable NSString *)value;
+ (void)record:(NSString *)kind channel:(nullable NSString *)channel count:(int64_t)count bytes:(int64_t)bytes reason:(NSString *)reason;
+ (void)batch:(NSString *)channel count:(int64_t)count bytes:(int64_t)bytes ageMs:(int64_t)age source:(NSString *)source;
+ (nullable FTDiagnosticsAttempt *)begin:(NSString *)channel payloadBytes:(int64_t)bytes;
@end
NS_ASSUME_NONNULL_END
