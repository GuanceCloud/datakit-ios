//
//  FTExternalResourceProtocol.h
//  FTMobileSDK
//
//  Created by hulilei on 2022/11/17.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTRumResourceProtocol.h"
NS_ASSUME_NONNULL_BEGIN

@protocol FTExternalResourceProtocol <NSObject,FTRumResourceProtocol>
///  获取 trace 需要添加的请求头
/// @param key 请求标识
/// @param url 请求 URL
- (nullable NSDictionary *)getTraceHeaderWithKey:(NSString *)key url:(NSURL *)url;

@end

NS_ASSUME_NONNULL_END
