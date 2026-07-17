//
//  FTExtensionManager.h
//  FTWidgetExtension
//
//  Created by hulilei on 2020/11/13.
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
#import "FTLoggerConfig.h"
#import "FTExtensionConfig.h"
NS_ASSUME_NONNULL_BEGIN
/// Manages SDK data collection and logging for an app extension.
@interface FTExtensionManager : NSObject
/// Starts extension data collection with the specified configuration.
/// - Parameter extensionConfig: Configuration shared by the host app and extension.
+ (void)startWithExtensionConfig:(FTExtensionConfig *)extensionConfig;

/// Returns the manager initialized by `startWithExtensionConfig:`.
+ (instancetype)sharedInstance;
/// Writes a custom log without additional properties.
/// - Parameters:
///   - content: Log content, which can be a JSON string.
///   - status: Log severity and status.
-(void)logging:(NSString *)content status:(FTLogStatus)status;
/// Add custom logs
/// - Parameters:
///   - content: log content, can be json string
///   - status: event level and status
///   - property: event custom properties (optional)
-(void)logging:(NSString *)content status:(FTLogStatus)status property:(nullable NSDictionary *)property;
@end

NS_ASSUME_NONNULL_END
