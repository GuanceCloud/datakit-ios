//
//  FTRemoteConfigModel+Private.h
//  FTMobileSDK
//
//  Created by hulilei on 2025/12/23.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import "FTRemoteConfigModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface FTRemoteConfigModel (Private)

@property (nonatomic, copy, readonly, nullable) NSString *md5Str;

@property (nonatomic, copy, readonly) NSDictionary *context;

- (instancetype)initWithDict:(NSDictionary *)dict;
- (instancetype)initWithDict:(NSDictionary *)dict md5:(NSString *)md5;

- (NSDictionary *)toDictionary;
@end

NS_ASSUME_NONNULL_END
