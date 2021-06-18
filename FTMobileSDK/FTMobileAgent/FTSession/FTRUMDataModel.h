//
//  FTRUMDataModel.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/5/25.
//  Copyright © 2021 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
@class FTTaskInterceptionModel;
typedef NS_ENUM(NSUInteger, FTRUMDataType) {
    FTRUMDataLaunchHot,
    FTRUMDataLaunchCold,
    FTRUMDataClick,
    FTRUMDataViewStart,
    FTRUMDataViewStop,
    FTRUMDataLongTask,
    FTRUMDataError,
    FTRUMDataResourceStart,
    FTRUMDataResourceSuccess,
    FTRUMDataResourceError,
    FTRUMDataWebViewJSBData,
};

NS_ASSUME_NONNULL_BEGIN
//tags
@interface FTRUMActionModel : NSObject
@property (nonatomic, copy) NSString *action_id;
@property (nonatomic, copy) NSString *action_name;
@property (nonatomic, copy) NSString *action_type;
-(instancetype)initWithActionID:(NSString *)actionid actionName:(NSString *)actionName actionType:(NSString *)actionType;

-(NSDictionary *)getActionTags;

@end
//tags
@interface FTRUMViewModel : NSObject
@property (nonatomic, copy) NSString *view_id;
@property (nonatomic, copy) NSString *view_name;
@property (nonatomic, copy) NSString *view_referrer;
@property (nonatomic, strong) NSNumber *loading_time;
-(instancetype)initWithViewID:(NSString *)viewid viewName:(NSString *)viewName viewReferrer:(NSString *)viewReferrer;
@end
//tags
@interface FTRUMSessionModel : NSObject
@property (nonatomic, copy) NSString *session_id;
@property (nonatomic, copy) NSString *session_type;
-(instancetype)initWithSessionID:(NSString *)sessionid;
@end
@interface FTRUMDataModel : NSObject

@property (nonatomic, strong) NSDate *time;
@property (nonatomic, assign) FTRUMDataType type;
@property (nonatomic, strong) NSDictionary *tags;
@property (nonatomic, strong) NSDictionary *fields;

@property (nonatomic, strong) FTRUMViewModel *baseViewData;
@property (nonatomic, strong) FTRUMActionModel *baseActionData;
@property (nonatomic, strong) FTRUMSessionModel *baseSessionData;
-(instancetype)initWithType:(FTRUMDataType)type time:(NSDate *)time;
-(NSDictionary *)getGlobalSessionViewTags;
@end

@interface FTRUMResourceDataModel : FTRUMDataModel
@property (nonatomic, copy) NSString *identifier;

-(instancetype)initWithType:(FTRUMDataType)type identifier:(NSString *)identifier;
@end
@interface FTRUMLaunchDataModel : FTRUMDataModel
@property (nonatomic, strong) NSNumber *duration;
-(instancetype)initWithType:(FTRUMDataType)type duration:(NSNumber *)duration;
@end
@interface FTRUMWebViewData : FTRUMDataModel
@property (nonatomic, assign) long long tm;
@property (nonatomic, copy) NSString *measurement;
-(instancetype)initWithMeasurement:(NSString *)measurement tm:(long long )tm;
@end


NS_ASSUME_NONNULL_END
