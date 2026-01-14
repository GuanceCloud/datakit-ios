//
//  FTRemoteConfigError.h
//
//  Created by hulilei on 2025/12/24.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
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
 *  @param minimumInterval Required minimum update interval (seconds)
 *  @return NSError instance with domain/code/description
 */
+ (NSError *)errorWithIntervalNotMet:(NSInteger)minimumInterval;

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


