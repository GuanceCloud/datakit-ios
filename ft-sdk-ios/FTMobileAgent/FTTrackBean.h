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
@property (nonatomic, strong) NSString *measurement;
@property (nonatomic, strong) NSDictionary *tags;
@property (nonatomic, strong) NSDictionary *field;
//需要为毫秒级13位时间戳
@property (nonatomic, assign) long long  timeMillis;
@end

NS_ASSUME_NONNULL_END
