//
//  FTRumResourceProtocol.h
//  FTMobileSDK
//
//  Created by hulilei on 2022/9/13.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
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


#ifndef FTRumResourceProtocol_h
#define FTRumResourceProtocol_h
NS_ASSUME_NONNULL_BEGIN

@class FTResourceMetricsModel,FTResourceContentModel;
@protocol FTRumResourceProtocol <NSObject>
/// HTTP request start
///
/// - Parameters:
///   - key: Request identifier
- (void)startResourceWithKey:(NSString *)key;
/// HTTP request start
/// - Parameters:
///   - key: Request identifier
///   - property: Event custom properties (optional)
- (void)startResourceWithKey:(NSString *)key property:(nullable NSDictionary *)property;

/// HTTP request data
///
/// - Parameters:
///   - key: Request identifier
///   - metrics: Request-related performance properties
///   - content: Request-related data
- (void)addResourceWithKey:(NSString *)key metrics:(nullable FTResourceMetricsModel *)metrics content:(FTResourceContentModel *)content;
/// HTTP request end
///
/// - Parameters:
///   - key: Request identifier
- (void)stopResourceWithKey:(NSString *)key;
/// HTTP request end
/// - Parameters:
///   - key: Request identifier
///   - property: Event custom properties (optional)
- (void)stopResourceWithKey:(NSString *)key property:(nullable NSDictionary *)property;
@optional
/// HTTP request data including tracer information spanID, traceID
/// - Parameters:
///   - key: Request identifier
///   - metrics: Request-related performance properties
///   - content: Request-related data
///   - spanID: tracer spanid
///   - traceID: tracer traceid
- (void)addResourceWithKey:(NSString *)key metrics:(nullable FTResourceMetricsModel *)metrics content:(FTResourceContentModel *)content spanID:(nullable NSString *)spanID traceID:(nullable NSString *)traceID;
@end
NS_ASSUME_NONNULL_END

#endif /* FTRumResourceHandler_h */
