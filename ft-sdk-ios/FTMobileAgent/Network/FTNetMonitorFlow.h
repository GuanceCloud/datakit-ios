//
//  FTNetMonitorFlow.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/1/9.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTNetMonitorFlow : NSObject
@property (nonatomic, assign) long long iflow;
@property (nonatomic, assign) long long oflow;

/**
 * 开始监控
*/
- (void)startMonitor;

/**
 * 停止监控
*/
- (void)stopMonitor;
@end

NS_ASSUME_NONNULL_END
