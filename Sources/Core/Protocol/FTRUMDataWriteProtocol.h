//
//  FTRUMDataWriteProtocol.h
//  FTMobileAgent
//
//  Created by hulilei on 2021/8/23.
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

#ifndef FTRUMDataWriteProtocol_h
#define FTRUMDataWriteProtocol_h
NS_ASSUME_NONNULL_BEGIN

/// RUM data write interface
@protocol FTRUMDataWriteProtocol <NSObject>

/// RUM data write
/// - Parameters:
///   - source: Data source view|action|resource|error
///   - tags: Properties
///   - fields: Metrics
///   - tm: Data generation timestamp (ns)
- (void)rumWrite:(NSString *)source tags:(NSDictionary *)tags fields:(NSDictionary *)fields dynamicContext:(NSDictionary *)dynamicContext time:(long long)time;


- (void)rumWrite:(NSString *)source tags:(NSDictionary *)tags fields:(NSDictionary *)fields dynamicContext:(NSDictionary *)dynamicContext time:(long long)time updateTime:(long long)updateTime;

- (void)rumWrite:(NSString *)source tags:(NSDictionary *)tags fields:(NSDictionary *)fields dynamicContext:(NSDictionary *)dynamicContext time:(long long)time updateTime:(long long)updateTime cache:(BOOL)cache;

- (void)rumWriteAssembledData:(NSString *)source tags:(NSDictionary *)tags fields:(NSDictionary *)fields time:(long long)time;
@optional
/// Returns the actual modifier/filter admission result synchronously. This is not
/// a persistence or upload acknowledgment. Compatibility writers may omit it.
- (BOOL)rumWriteAccepted:(NSString *)source tags:(NSDictionary *)tags fields:(NSDictionary *)fields dynamicContext:(NSDictionary *)dynamicContext time:(long long)time;
/// Write RUM data collected by extension widget
/// - Parameters:
///   - source: Data source view|action|resource|error
///   - tags: Properties
///   - fields: Metrics
///   - time: Data generation timestamp (ns)
- (void)extensionRumWrite:(NSString *)source tags:(NSDictionary *)tags fields:(NSDictionary *)fields time:(long long)time;

/// Switch to cache writer for session on error data, data type is RUMCache
- (void)isCacheWriter:(BOOL)cache;

/// Whether the last APP has written local data for crashes, ANR, etc., errorDate is the crash time
- (void)lastFatalErrorIfFound:(long long)errorDate;

/// Process rum cache data, check if deletion is needed
- (void)checkRUMSessionOnErrorDatasWithExpireTime:(long long)expireTime;
@end
/// Write once, using the writer's existing filtering decision when available.
NS_INLINE BOOL FTRUMWriteAccepted(id<FTRUMDataWriteProtocol> writer, NSString *source, NSDictionary *tags, NSDictionary *fields, NSDictionary *context, long long time) {
    if (!writer) return NO;
    if ([writer respondsToSelector:@selector(rumWriteAccepted:tags:fields:dynamicContext:time:)]) {
        return [writer rumWriteAccepted:source tags:tags fields:fields dynamicContext:context time:time];
    }
    [writer rumWrite:source tags:tags fields:fields dynamicContext:context time:time];
    return YES;
}
NS_ASSUME_NONNULL_END
#endif /* FTRUMDataWriteProtocol_h */
