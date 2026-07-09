//
//  FTSessionManger.h
//  FTMobileAgent
//
//  Created by hulilei on 2021/5/21.
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

#import "FTRUMHandler.h"
#import "FTInternalConstants.h"
#import "FTErrorDataProtocol.h"
#import "FTRumDatasProtocol.h"
#import "FTRumResourceProtocol.h"
#import "FTLinkRumDataProvider.h"
#import "FTWKWebViewRumDelegate.h"

@class FTResourceMetricsModel,FTResourceContentModel;

NS_ASSUME_NONNULL_BEGIN

@interface FTRUMManager : FTRUMHandler<FTRumResourceProtocol,FTErrorDataDelegate,FTRumDatasProtocol,FTLinkRumDataProvider,FTWKWebViewRumDelegate>
@property (nonatomic, assign) FTAppState appState;

#pragma mark - init -
-(instancetype)initWithRumDependencies:(FTRUMDependencies *)dependencies;
-(void)updateSampleRate:(int)sampleRate sessionOnErrorSampleRate:(int)sessionOnErrorSampleRate;
#pragma mark - resource -
/// HTTP request start
///
/// - Parameters:
///   - key: Request identifier
- (void)startResourceWithKey:(NSString *)key;
/// HTTP request start
/// - Parameters:
///   - key: Request identifier
///   - property: Custom event properties (optional)
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
///   - property: Custom event properties (optional)
- (void)stopResourceWithKey:(NSString *)key property:(nullable NSDictionary *)property;

#pragma mark - Error / Long Task -


/// Freeze
/// @param stack Freeze stack
/// @param duration Freeze duration
- (void)addLongTaskWithStack:(nonnull NSString *)stack duration:(nonnull NSNumber *)duration startTime:(long long)time;
/**
 * Freeze
 * @param stack      Freeze stack
 * @param duration   Freeze duration
 * @param property   Event properties (optional)
 */
- (void)addLongTaskWithStack:(NSString *)stack duration:(NSNumber *)duration startTime:(long long)time property:(nullable NSDictionary *)property;

/// Wait for all rum processing data to be processed
- (void)syncProcess;
@end

NS_ASSUME_NONNULL_END
