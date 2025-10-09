//
//  FTRUMDataModel.h
//  FTMobileAgent
//
//  Created by hulilei on 2021/5/25.
//  Copyright © 2021 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
typedef NS_ENUM(NSUInteger, FTRUMDataType) {
    FTRUMSDKInit,
    FTRUMDataLaunch,
    FTRUMDataStartAction,
    FTRUMDataAddAction,
    FTRUMDataStopAction,
    FTRUMDataViewStart,
    FTRUMDataViewUpdateLoadingTime,
    FTRUMDataViewStop,
    FTRUMDataLongTask,
    FTRUMDataError,
    FTRUMDataResourceStart,
    FTRUMDataResourceComplete,
    FTRUMDataResourceAbandon,
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
@property (nonatomic, assign) long long tm;
-(instancetype)initWithType:(FTRUMDataType)type time:(NSDate *)time;
@end
/// Data model for handling Action events
@interface FTRUMActionModel : FTRUMDataModel
@property (nonatomic, copy) NSString *action_name;
@property (nonatomic, copy) NSString *action_type;
-(instancetype)initWithActionName:(NSString *)actionName actionType:(NSString *)actionType;

@end
/// Data model for handling View events
@interface FTRUMViewModel : FTRUMDataModel
@property (nonatomic, copy) NSString *view_id;
@property (nonatomic, copy) NSString *view_name;
@property (nonatomic, copy) NSString *view_referrer;
@property (nonatomic, strong) NSNumber *loading_time;
-(instancetype)initWithViewID:(NSString *)viewID viewName:(NSString *)viewName viewReferrer:(NSString *)viewReferrer;
@end

@interface FTRUMViewLoadingModel : FTRUMDataModel

@property (nonatomic, strong) NSNumber *duration;
-(instancetype)initWithDuration:(NSNumber *)duration;
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
@property (nonatomic, copy) NSString *measurement;
-(instancetype)initWithMeasurement:(NSString *)measurement tm:(long long )tm;
@end
@interface FTRUMErrorData : FTRUMDataModel
@property (nonatomic, assign) BOOL fatal;
@end
@interface FTRUMContext : NSObject
@property (nonatomic, copy) NSString *app_id;
@property (nonatomic, copy) NSString *session_id;
@property (nonatomic, copy) NSString *session_type;
@property (nonatomic, copy) NSString *view_id;
@property (nonatomic, copy) NSString *view_name;
@property (nonatomic, copy) NSString *view_referrer;
@property (nonatomic, copy, nullable) NSString *action_id;
@property (nonatomic, copy, nullable) NSString *action_name;
@property (nonatomic, assign) long long session_error_timestamp;
@property (nonatomic, assign) BOOL sampled_for_error_session;

- (instancetype)initWithAppID:(NSString *)appID;

/// trace, logger get rum correlation data
-(NSDictionary *)getGlobalSessionViewTags;
/// rum internal get related correlation data
-(NSDictionary *)getGlobalSessionViewActionTags;
-(NSDictionary *)getGlobalSessionTags;
@end
NS_ASSUME_NONNULL_END
