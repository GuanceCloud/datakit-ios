//
//  FTRemoteConfigError.h
//
//  Created by hulilei on 2025/12/24.
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
#import "FTRemoteConfigTypeDefs.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  Remote Configuration Error Utility Class
 *  Unified management of error creation, error descriptions and error domain
 */
@interface FTRemoteConfigError : NSObject

/**
 *  Create error instance for "Remote config is disabled"
 *  @return NSError instance with domain/code/description
 */
+ (NSError *)errorWithDisabled;

/**
 *  Create error instance for "Update interval not met"
 *  @param tipMessage Required update interval (seconds)
 *  @return NSError instance with domain/code/description
 */
+ (NSError *)errorWithIntervalNotMet:(NSString *)tipMessage;

/**
 *  Create error instance for "Request is in progress"
 *  @return NSError instance with domain/code/description
 */
+ (NSError *)errorWithRequesting;

/**
 *  Create error instance for "Network request failed"
 *  @param underlyingError Original network error (can be nil)
 *  @return NSError instance with domain/code/description
 */
+ (NSError *)errorWithNetworkFailed:(nullable NSError *)underlyingError;

/**
 *  Create error instance for "Config parse failed"
 *  @param reason Detailed parse failure reason (can be nil)
 *  @return NSError instance with domain/code/description
 */
+ (NSError *)errorWithParseFailed:(nullable NSString *)reason;

/**
 *  Create error instance for "SDK is not initialized"
 *  @return NSError instance with domain/code/description
 */
+ (NSError *)errorWithSDKNotInitialized;

/**
 *  Create custom error instance with specified code and description
 *  @param code Error code from FTRemoteConfigErrorCode
 *  @param description Custom error description (if nil, use default description)
 *  @return NSError instance with domain/code/description
 */
+ (NSError *)errorWithCode:(FTRemoteConfigErrorCode)code customDescription:(nullable NSString *)description;

@end

NS_ASSUME_NONNULL_END


