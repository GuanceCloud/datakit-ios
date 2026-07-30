//
//  FTRUMDataModel.h
//  FTMobileAgent
//
//  Created by hulilei on 2021/5/25.
//  Copyright 2021 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import <Foundation/Foundation.h>
typedef NS_ENUM(NSUInteger, FTRUMDataType) {
    FTRUMViewPlaceholder,
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
    FTRUMSRLinkInfo,
    FTRUMSampleRateUpdate,
};

NS_ASSUME_NONNULL_BEGIN
@class FTResourceMetricsModel,FTResourceContentModel,FTHeatmapAttributes;
@interface FTRUMDataModel : NSObject
@property (nonatomic, strong) NSDate *time;
@property (nonatomic, assign) FTRUMDataType type;
@property (nonatomic, strong) NSDictionary *tags;
@property (nonatomic, strong) NSDictionary *fields;
@property (nonatomic, assign) long long tm;
@property (nonatomic, assign, readonly) BOOL isUserInteraction;
-(instancetype)initWithType:(FTRUMDataType)type time:(NSDate *)time;
@end
/// Data model for handling Action events
@interface FTRUMActionModel : FTRUMDataModel
@property (nonatomic, copy) NSString *action_name;
@property (nonatomic, copy) NSString *action_type;
@property (nonatomic, strong, nullable) FTHeatmapAttributes *heatmapAttributes;
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
/// Keeps the Resource lifecycle duration when metrics provide an independent task interval.
@property (nonatomic, assign) BOOL keepsResourceDuration;
@end
@interface FTRUMLaunchDataModel : FTRUMActionModel
@property (nonatomic, strong) NSNumber *duration;
@property (nonatomic, assign, readonly) BOOL isInitialLaunchAction;
-(instancetype)initWithDuration:(NSNumber *)duration;
@end
@interface FTRUMWebViewData : FTRUMDataModel
@property (nonatomic, copy) NSString *measurement;
-(instancetype)initWithMeasurement:(NSString *)measurement tm:(long long )tm;
@end
@interface FTRUMSRLinkInfoData : FTRUMDataModel
@property (nonatomic, copy) NSString *view_id;
@end

@interface FTRUMErrorData : FTRUMDataModel
@end
NS_ASSUME_NONNULL_END
