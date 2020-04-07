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
@property (nonatomic, assign) long long flow;
//开始检测

- (void)startMonitor;

//停止检测

- (void)stopMonitor;
@end

NS_ASSUME_NONNULL_END
