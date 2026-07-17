//
//  FTRumConfig+Private.h
//  FTMobileSDK
//
//  Created by hulilei on 2025/7/22.
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

#import "FTRumConfig.h"

NS_ASSUME_NONNULL_BEGIN
@class FTRemoteConfigModel;
@interface FTRumConfig ()
/// Private initialization method, initialized through dictionary, used for Extension SDK
/// - Parameter dict: dictionary converted from config
-(instancetype)initWithDictionary:(NSDictionary *)dict;
/// Convert config to dictionary
-(NSDictionary *)convertToDictionary;
@end

NS_ASSUME_NONNULL_END
