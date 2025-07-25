//
//  FTMobileConfig+Private.h
//  FTMobileSDK
//
//  Created by hulilei on 2022/10/17.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import "FTMobileConfig.h"
#import "FTLoggerConfig+Private.h"
#import "FTRumConfig+Private.h"
NS_ASSUME_NONNULL_BEGIN
@interface FTMobileConfig ()
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

/// Merge remote config
-(void)mergeWithRemoteConfigDict:(NSDictionary *)dict;
@end


@interface FTTraceConfig ()
/// Private initialization method, initialized through dictionary, used for Extension SDK
/// - Parameter dict: dictionary converted from config
-(instancetype)initWithDictionary:(NSDictionary *)dict;
/// Convert config to dictionary
-(NSDictionary *)convertToDictionary;
/// Merge remote config
-(void)mergeWithRemoteConfigDict:(NSDictionary *)dict;
@end
NS_ASSUME_NONNULL_END
