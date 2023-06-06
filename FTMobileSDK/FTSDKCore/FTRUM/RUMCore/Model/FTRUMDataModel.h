//
//  FTRUMDataModel.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/5/25.
//  Copyright © 2021 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTRUMDataWriteProtocol.h"
typedef NS_ENUM(NSUInteger, FTRUMDataType) {
    FTRUMDataLaunch,
    FTRUMDataClick,
    FTRUMDataViewStart,
    FTRUMDataViewStop,
    FTRUMDataLongTask,
    FTRUMDataError,
    FTRUMDataResourceStart,
    FTRUMDataResourceComplete,
    FTRUMDataResourceStop,
    FTRUMDataResourceError,
    FTRUMDataWebViewJSBData,
};

NS_ASSUME_NONNULL_BEGIN
@class FTResourceMetricsModel,FTResourceContentModel;
@interface FTRUMDataModel : NSObject
@property (nonatomic, strong) NSDate *time;
@property (nonatomic, assign) FTRUMDataType type;
@property (nonatomic, strong) NSDictionary *tags;
@property (nonatomic, strong) NSDictionary *fields;

-(instancetype)initWithType:(FTRUMDataType)type time:(NSDate *)time;
@end
/// 处理 Action 事件的数据模型
@interface FTRUMActionModel : FTRUMDataModel
@property (nonatomic, copy) NSString *action_name;
@property (nonatomic, copy) NSString *action_type;
-(instancetype)initWithActionName:(NSString *)actionName actionType:(NSString *)actionType;

@end
/// 处理 View 事件的数据模型
@interface FTRUMViewModel : FTRUMDataModel
@property (nonatomic, copy) NSString *view_id;
@property (nonatomic, copy) NSString *view_name;
@property (nonatomic, copy) NSString *view_referrer;
@property (nonatomic, strong) NSNumber *loading_time;
-(instancetype)initWithViewID:(NSString *)viewid viewName:(NSString *)viewName viewReferrer:(NSString *)viewReferrer;
@end

@interface FTRUMResourceModel : FTRUMDataModel
@property (nonatomic, copy) NSString *identifier;

-(instancetype)initWithType:(FTRUMDataType)type identifier:(NSString *)identifier;
@end
@interface FTRUMResourceDataModel : FTRUMResourceModel
@property (nonatomic, strong) FTResourceMetricsModel *metrics;
@end
@interface FTRUMLaunchDataModel : FTRUMActionModel
@property (nonatomic, strong) NSNumber *duration;
-(instancetype)initWithDuration:(NSNumber *)duration;
@end
@interface FTRUMWebViewData : FTRUMDataModel
@property (nonatomic, assign) long long tm;
@property (nonatomic, copy) NSString *measurement;
-(instancetype)initWithMeasurement:(NSString *)measurement tm:(long long )tm;
@end
@interface FTRUMErrorData : FTRUMDataModel
@property (nonatomic, assign) BOOL fatal;
@end
@interface FTRUMContext : NSObject
@property (nonatomic, copy) NSString *session_id;
@property (nonatomic, copy) NSString *session_type;
@property (nonatomic, copy) NSString *view_id;
@property (nonatomic, copy) NSString *view_name;
@property (nonatomic, copy) NSString *view_referrer;
@property (nonatomic, copy, nullable) NSString *action_id;
@property (nonatomic, copy, nullable) NSString *action_name;
@property (nonatomic, weak) id<FTRUMDataWriteProtocol> writer;
-(NSDictionary *)getGlobalSessionViewTags;
-(NSDictionary *)getGlobalSessionViewActionTags;
@end
NS_ASSUME_NONNULL_END
