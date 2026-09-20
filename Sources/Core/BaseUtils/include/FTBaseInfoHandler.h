//
//  FTBaseInfoHandler.h
//  FTMobileAgent
//
//  Created by hulilei on 2019/12/3.
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
#import "FTSDKCompat.h"
NS_ASSUME_NONNULL_BEGIN

/// Utility methods
@interface FTBaseInfoHandler : NSObject


/// Convert dictionary to string
/// - Parameter dict: Dictionary to convert
+ (NSString *)convertToStringData:(NSDictionary *)dict;

/// url_path_group processing
/// - Parameter url: URL
+ (NSString *)replaceNumberCharByUrl:(NSURL *)url;

/// Sampling rate determination
/// - Parameter sampling: User-set sampling rate
/// - Returns: Whether to perform sampling
+ (BOOL)randomSampling:(int)sampling;
/// Get random uuid string (no `-`, all lowercase)
+ (NSString *)randomUUID;
+ (NSString *)random16UUID;

/// Device IP Address
/// - Parameter preferIPv4 Whether to prefer IPv4
+ (NSString *)cellularIPAddress:(BOOL)preferIPv4;


@end

NS_ASSUME_NONNULL_END
