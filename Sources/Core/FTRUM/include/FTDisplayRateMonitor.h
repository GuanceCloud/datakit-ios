//
//  FTDisplayRate.h
//  FTMobileAgent
//
//  Created by hulilei on 2022/6/30.
//  Copyright 2022 Shanghai Guance Information Technology Co., Ltd.
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
@class FTReadWriteHelper,FTMonitorValue;
NS_ASSUME_NONNULL_BEGIN

/// FPS monitor
@interface FTDisplayRateMonitor : NSObject
/// Whether DisplayLink should follow app active/resign lifecycle. Enable this for continuous FPS monitoring.
@property (nonatomic, assign) BOOL autoStartWithAppLifecycle;

/// Add monitoring item, each ViewHandler in RUM contains a monitoring item to monitor data during the View lifecycle
/// - Parameter item: monitoring item
- (void)addMonitorItem:(FTReadWriteHelper *)item;

/// Remove monitoring item
/// - Parameter item: monitoring item
- (void)removeMonitorItem:(FTReadWriteHelper *)item;

/// Start DisplayLink
- (void)start;

/// Stop DisplayLink
- (void)stop;
@end

NS_ASSUME_NONNULL_END
