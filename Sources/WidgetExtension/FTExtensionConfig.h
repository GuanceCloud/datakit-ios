//
//  FTExtensionConfig.h
//  FTWidgetExtension
//
//  Created by hulilei on 2022/10/17.
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

NS_ASSUME_NONNULL_BEGIN

/// Configuration for collecting RUM, tracing, and logging data from an app extension.
@interface FTExtensionConfig : NSObject

/// File sharing Group Identifier. (Required)
@property (nonatomic, copy) NSString *groupIdentifier;

/// Set whether to allow SDK to print Debug logs
@property (nonatomic, assign) BOOL enableSDKDebugLog;

/// Set whether to collect crash logs
@property (nonatomic, assign) BOOL enableTrackAppCrash;

/// Set whether to enable automatic collection of http Resource events in RUM
@property (nonatomic, assign) BOOL enableRUMAutoTraceResource;

/// Set whether to enable automatic http link tracing
@property (nonatomic, assign) BOOL enableTracerAutoTrace;

/// Maximum number of data items saved in Extension
///
/// Default 1000 items, delete old data and save new data when limit is reached
@property (nonatomic, assign) NSInteger memoryMaxCount;

/// Initialization method, set required parameter groupIdentifier
/// - Parameter groupIdentifier: File sharing Group Identifier
- (instancetype)initWithGroupIdentifier:(NSString *)groupIdentifier;
@end

NS_ASSUME_NONNULL_END
