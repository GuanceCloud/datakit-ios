//
//  FTGlobalRumManager.h
//  FTMobileAgent
//
//  Created by hulilei on 2020/4/14.
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
#import "FTRumDatasProtocol.h"
NS_ASSUME_NONNULL_BEGIN
@class FTResourceMetricsModel,FTResourceContentModel;

/// Class for managing RUM, used to enable collection of various RUM data
@interface FTGlobalRumManager : NSObject

/// Singleton
+ (instancetype)sharedInstance;

/// Singleton
+ (instancetype)sharedManager;

#pragma mark --------- Rum ----------
/// Create RUM View
///
/// Called before the `-startViewWithName` method, this method is used to record the page loading time. If the loading time cannot be obtained, this method can be omitted.
/// - Parameters:
///   - viewName: RUM View name
///   - loadTime: page loading time
-(void)onCreateView:(NSString *)viewName loadTime:(NSNumber *)loadTime;
/// Starts RUM view
///
/// - Parameters:
///   - viewName: RUM View name
-(void)startViewWithName:(NSString *)viewName;

/// Starts RUM view
/// - Parameters:
///   - viewName: RUM View name
///   - property: event custom properties (optional)
-(void)startViewWithName:(NSString *)viewName property:(nullable NSDictionary *)property;

/// Stop RUM View.
-(void)stopView;

/// Stop RUM View.
/// - Parameter property: event custom properties (optional)
-(void)stopViewWithProperty:(nullable NSDictionary *)property;

/// Add Action event
///
/// - Parameters:
///   - actionName: event name
///   - actionType: event type
- (void)addActionName:(NSString *)actionName actionType:(NSString *)actionType;
/// Add Action event
/// - Parameters:
///   - actionName: event name
///   - actionType: event type
///   - property: event custom properties (optional)
- (void)addActionName:(NSString *)actionName actionType:(NSString *)actionType property:(nullable NSDictionary *)property;

/// Add Error event
///
/// - Parameters:
///   - type: error type
///   - message: error message
///   - stack: stack information
- (void)addErrorWithType:(NSString *)type message:(NSString *)message stack:(NSString *)stack;
/// Add Error event
/// - Parameters:
///   - type: error type
///   - message: error message
///   - stack: stack information
///   - property: event custom properties (optional)
- (void)addErrorWithType:(NSString *)type message:(NSString *)message stack:(NSString *)stack property:(nullable NSDictionary *)property;

/// Add Error event
/// - Parameters:
///   - type: error type
///   - state: program running state
///   - message: error message
///   - stack: stack information
///   - property: event custom properties (optional)
- (void)addErrorWithType:(NSString *)type state:(FTAppState)state message:(NSString *)message stack:(NSString *)stack property:(nullable NSDictionary *)property;

/// Add freeze event
///
/// - Parameters:
///   - stack: freeze stack
///   - duration: freeze duration (nanoseconds)
- (void)addLongTaskWithStack:(NSString *)stack duration:(NSNumber *)duration;

/// Add freeze event
/// - Parameters:
///   - stack: freeze stack
///   - duration: freeze duration (nanoseconds)
///   - property: event custom properties (optional)
- (void)addLongTaskWithStack:(NSString *)stack duration:(NSNumber *)duration property:(nullable NSDictionary *)property;

/// HTTP request start
///
/// - Parameters:
///   - key: request identifier
- (void)startResourceWithKey:(NSString *)key;
/// HTTP request start
/// - Parameters:
///   - key: request identifier
///   - property: event custom properties (optional)
- (void)startResourceWithKey:(NSString *)key property:(nullable NSDictionary *)property;

/// HTTP add request data
///
/// - Parameters:
///   - key: request identifier
///   - metrics: request-related performance properties
///   - content: request-related data
- (void)addResourceWithKey:(NSString *)key metrics:(nullable FTResourceMetricsModel *)metrics content:(FTResourceContentModel *)content;
/// HTTP request end
///
/// - Parameters:
///   - key: request identifier
- (void)stopResourceWithKey:(NSString *)key;
/// HTTP request end
/// - Parameters:
///   - key: request identifier
///   - property: event custom properties (optional)
- (void)stopResourceWithKey:(NSString *)key property:(nullable NSDictionary *)property;

@end

NS_ASSUME_NONNULL_END
