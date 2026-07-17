//
//  FTSDKConfig+Private.h
//  FTMobileSDK
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

#import "FTSDKConfig.h"

NS_ASSUME_NONNULL_BEGIN
@interface FTSDKConfig ()
/// Add package information
/// - Parameters:
///   - key: platform
///   - value: version number
- (void)addPkgInfo:(NSString *)key value:(NSString *)value;
/// Other platform package information
- (NSDictionary *)pkgInfo;
/// Private initialization method, initialized through dictionary, used for Extension SDK, sync service
/// - Parameter dict: dictionary converted from config
-(instancetype)initWithDictionary:(NSDictionary *)dict;
/// Convert config to dictionary
-(NSDictionary *)convertToDictionary;

@end


@interface FTTraceConfig ()
/// Private initialization method, initialized through dictionary, used for Extension SDK
/// - Parameter dict: dictionary converted from config
-(instancetype)initWithDictionary:(NSDictionary *)dict;
/// Convert config to dictionary
-(NSDictionary *)convertToDictionary;
@end
NS_ASSUME_NONNULL_END
