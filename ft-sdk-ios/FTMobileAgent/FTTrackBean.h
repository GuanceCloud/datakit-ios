//
//  FTTrackBean.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/3/12.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
///事件等级和状态，info：提示，warning：警告，error：错误，critical：严重，ok：恢复，默认：info
typedef NS_ENUM(NSInteger, FTStatus) {
    FTStatusInfo         = 0,
    FTStatusWarning,
    FTStatusError,
    FTStatusCritical,
    FTStatusOk,
};
NS_ASSUME_NONNULL_BEGIN

@interface FTTrackBean : NSObject
//当前数据点所属的指标集 （必填）
@property (nonatomic, copy) NSString *measurement;
//自定义标签  （可选）
@property (nonatomic, strong) NSDictionary *tags;
//自定义指标  （必填）
@property (nonatomic, strong) NSDictionary *field;
//需要为毫秒级13位时间戳 （可选） 不传则为当前时间
@property (nonatomic, assign) long long  timeMillis;
@end


NS_ASSUME_NONNULL_END
