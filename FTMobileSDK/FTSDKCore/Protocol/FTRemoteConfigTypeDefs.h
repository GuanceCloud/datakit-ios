//
//  FTRemoteConfigTypeDefs.h
//
//  Created by hulilei on 2025/12/24.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FTRemoteConfigModel;
/**
 * Remote configuration fetch completion Block type (success + error + data)
 * @param success  Whether the remote configuration fetch operation succeeds (network/parsing layer, YES = success, NO = failure). Note: Success does not guarantee non-empty data.
 * @param error    Error information when the fetch/parsing operation fails (nil when success=YES, regardless of data presence)
 * @param model    Parsed configuration model (nil if success=NO, or success=YES but fetched data is empty)
 * @param content  Raw configuration dictionary (nil if success=NO, or success=YES but fetched data is empty)
 * @return         For success: Modified FTRemoteConfigModel (SDK adjusts features by this) or nil (use original model).
 *                 For failure: Return nil (SDK ignores it).
 */
typedef FTRemoteConfigModel*_Nullable(^FTRemoteConfigFetchCompletionBlock)(BOOL success,
                                              NSError * _Nullable error,
                                              FTRemoteConfigModel * _Nullable model,
                                              NSDictionary<NSString *, id> * _Nullable content);


typedef NS_ENUM(NSInteger, FTRemoteConfigErrorCode) {
    FTRemoteConfigErrorCodeDisabled = 1001,           // Remote config is disabled
    FTRemoteConfigErrorCodeIntervalNotMet = 1002,     // Update interval not met
    FTRemoteConfigErrorCodeRequesting = 1003,         // Request is in progress
    FTRemoteConfigErrorCodeNetworkFailed = 1004,      // Network request failed
    FTRemoteConfigErrorCodeParseFailed = 1005,        // Config parse failed
    FTRemoteConfigErrorCodeSDKNotInitialized = 1006   // SDK is not initialized
};
