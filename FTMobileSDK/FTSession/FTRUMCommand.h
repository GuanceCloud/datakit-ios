//
//  FTRUMModel.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/5/25.
//  Copyright © 2021 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
@class FTTaskInterceptionModel;
typedef NS_ENUM(NSUInteger, FTRUMCommandType) {
    FTRUMDataLaunchHot,
    FTRUMDataLaunchCold,
    FTRUMDataClick,
    FTRUMDataViewStart,
    FTRUMDataViewStop,
    FTRUMDataViewLongTask,
    FTRUMDataViewError,
    FTRUMDataViewResourceStart,
    FTRUMDataViewResourceSuccess,
    FTRUMDataViewResourceError
};
/**
 NSString * const FT_TYPE_RESOURCE = @"resource";
 NSString * const FT_TYPE_CRASH = @"crash";
 NSString * const FT_TYPE_FREEZE = @"freeze";
 NSString * const FT_TYPE_VIEW = @"view";
 NSString * const FT_TYPE_ERROR = @"error";
 NSString * const FT_TYPE_ACTION = @"action";
 NSString * const FT_TYPE_LONG_TASK = @"long_task";
 */
NS_ASSUME_NONNULL_BEGIN
//tags
@interface FTRUMActionModel : NSObject
@property (nonatomic, copy) NSString *action_id;
@property (nonatomic, copy) NSString *action_name;
@property (nonatomic, copy) NSString *action_type;
-(instancetype)initWithActionID:(NSString *)actionid actionName:(NSString *)actionName actionType:(NSString *)actionType;
@end
//tags
@interface FTRUMViewModel : NSObject
@property (nonatomic, copy) NSString *view_id;
@property (nonatomic, copy) NSString *view_name;
@property (nonatomic, copy) NSString *view_referrer;
-(instancetype)initWithViewID:(NSString *)viewid viewName:(NSString *)viewName viewReferrer:(NSString *)viewReferrer;
@end
//tags
@interface FTRUMSessionModel : NSObject
@property (nonatomic, copy) NSString *session_id;
@property (nonatomic, copy) NSString *session_type;
-(instancetype)initWithSessionID:(NSString *)sessionid;
@end
@interface FTRUMCommand : NSObject

@property (nonatomic, strong) NSDate *time;
@property (nonatomic, assign) FTRUMCommandType type;
@property (nonatomic, strong) NSDictionary *tags;
@property (nonatomic, strong) NSDictionary *fields;

@property (nonatomic, strong) FTRUMViewModel *baseViewData;
@property (nonatomic, strong) FTRUMActionModel *baseActionData;
@property (nonatomic, strong) FTRUMSessionModel *baseSessionData;
-(instancetype)initWithType:(FTRUMCommandType)type time:(NSDate *)time;
@end
@interface FTRUMActionCommand : FTRUMCommand

@end
@interface FTRUMErrorCommand : FTRUMCommand

@end
@interface FTRUMResourceCommand : FTRUMCommand
@property (nonatomic, copy) NSString *identifier;

-(instancetype)initWithType:(FTRUMCommandType)type identifier:(NSString *)identifier;
@end

NS_ASSUME_NONNULL_END
