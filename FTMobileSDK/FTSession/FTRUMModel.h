//
//  FTRUMModel.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/5/25.
//  Copyright © 2021 hll. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, FTRUMDataType) {
    FTRUMDataLaunchHot,
    FTRUMDataLaunchCold,
    ActionClick,
    ActionView
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
@interface FTRUMActionModel : NSObject
@property (nonatomic, copy) NSString *action_id;
@property (nonatomic, copy) NSString *action_name;
@end
@interface FTRUMViewModel : NSObject
@property (nonatomic, copy) NSString *view_id;
@property (nonatomic, copy) NSString *view_name;
@property (nonatomic, copy) NSString *view_referrer;
@end

@interface FTRUMModel : NSObject

@property (nonatomic, strong) NSDate *time;

@property (nonatomic, strong) NSDictionary *tags;

@property (nonatomic, strong) NSDictionary *fields;

@property (nonatomic, strong) FTRUMViewModel *baseViewData;

@property (nonatomic, strong) FTRUMActionModel *baseActionData;
@end

@interface FTRUMErrorModel : NSObject
@end

NS_ASSUME_NONNULL_END
