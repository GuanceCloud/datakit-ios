//
//  FTBaseInfoHandler.h
//  FTMobileAgent
//
//  Created by hulilei on 2019/12/3.
//  Copyright © 2019 hll. All rights reserved.
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
#if FT_HOST_IOS
/// Telephony carrier
+(NSString *)telephonyCarrier;
#endif
/// Device IP Address
/// - Parameter preferIPv4 Whether to prefer IPv4
+ (NSString *)cellularIPAddress:(BOOL)preferIPv4;


@end

NS_ASSUME_NONNULL_END
