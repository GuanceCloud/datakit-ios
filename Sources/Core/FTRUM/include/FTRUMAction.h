//
//  FTRUMAction.h
//  FTMobileSDK
//
//  Created by hulilei on 2025/7/30.
//  Copyright 2025 Shanghai Guance Information Technology Co., Ltd.
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
/// Parameters that describe a RUM action before it is recorded.
@interface FTRUMAction : NSObject

/// The RUM Action name
@property (nonatomic, copy) NSString *actionName;
/// The RUM Action extra property
@property (nonatomic, copy, nullable) NSDictionary *property;

/// Initialization method
/// - Parameter actionName: Set the RUM Action name
-(instancetype)initWithActionName:(NSString *)actionName;

/// Initialization method
/// - Parameters:
///   - actionName: Set the RUM Action name
///   - property: Set the RUM Action extra property
-(instancetype)initWithActionName:(NSString *)actionName property:(nullable NSDictionary *)property;
@end
NS_ASSUME_NONNULL_END
