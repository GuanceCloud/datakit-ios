//
//  FTTrackBean.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/3/12.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTTrackBean : NSObject
//当前数据点所属的指标集
@property (nonatomic, strong) NSString *measurement;
//自定义标签
@property (nonatomic, strong) NSDictionary *tags;
//自定义指标
@property (nonatomic, strong) NSDictionary *field;
//需要为毫秒级13位时间戳
@property (nonatomic, assign) long long  timeMillis;
@end

NS_ASSUME_NONNULL_END
