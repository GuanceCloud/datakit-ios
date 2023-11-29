//
//  FTSessionConfiguration.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/4/21.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTSessionConfiguration : NSObject
/// 是否允许拦截 （开启自动采集时允许）
@property (atomic,assign,readonly) BOOL shouldIntercept;

+ (FTSessionConfiguration *)defaultConfiguration;
/// 开始 URLProtocol 监控
- (void)startMonitor;
/// 停止 URLProtocol 监控
- (void)stopMonitor;
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request delegate:(id<NSURLSessionDataDelegate>)delegate modes:(NSArray *)modes;
- (void)shutDown;
@end

NS_ASSUME_NONNULL_END
