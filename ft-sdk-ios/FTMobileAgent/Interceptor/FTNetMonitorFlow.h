//
//  network.h
//  testdemo
//
//  Created by 胡蕾蕾 on 2020/1/9.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTNetMonitorFlow : NSObject
//开始检测
//@property (nonatomic, copy) void(^updateNetFlowBlock)(NSString *flow);

- (void)startMonitor;

////停止检测
//
//- (void)stopMonitor;
- (NSString *)refreshFlow;
@end

NS_ASSUME_NONNULL_END
