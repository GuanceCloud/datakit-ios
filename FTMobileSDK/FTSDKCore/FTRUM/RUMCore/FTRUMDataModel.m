//
//  FTRUMDataModel.m
//  FTMobileAgent
//
//  Created by hulilei on 2021/5/25.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTRUMDataModel.h"
#import "FTConstants.h"
#import "FTBaseInfoHandler.h"
#import "NSDate+FTUtil.h"
@interface FTRUMDataModel()
@end
@implementation FTRUMDataModel
-(instancetype)init{
    self = [super init];
    if (self) {
        self.time = [NSDate date];
    }
    return self;
}
-(instancetype)initWithType:(FTRUMDataType)type time:(NSDate *)time{
    self = [super init];
    if (self) {
        self.time = time;
        self.type = type;
    }
    return self;
}
-(long long)tm{
    if(_tm>0){
        return _tm;
    }
    return [self.time ft_nanosecondTimeStamp];
}
@end
@implementation FTRUMViewModel
-(instancetype)initWithViewID:(NSString *)viewID viewName:(NSString *)viewName viewReferrer:(NSString *)viewReferrer{
    self = [super init];
    if (self) {
        self.view_id = viewID;
        self.view_name = viewName;
        self.view_referrer = viewReferrer;
    }
    return self;
}
@end

@implementation FTRUMViewLoadingModel
-(instancetype)initWithDuration:(NSNumber *)duration{
    self = [super initWithType:FTRUMDataViewUpdateLoadingTime time:[NSDate date]];
    if (self) {
        self.duration = duration;
    }
    return self;
}

@end
@implementation FTRUMActionModel

-(instancetype)initWithActionName:(NSString *)actionName actionType:(nonnull NSString *)actionType{
    self = [super init];
    if (self) {
        self.action_name = actionName;
        self.action_type = actionType;
    }
    return self;
}

@end
@implementation FTRUMResourceModel

-(instancetype)initWithType:(FTRUMDataType)type identifier:(NSString *)identifier{
    self = [super initWithType:type time:[NSDate date]];
    if (self) {
        self.identifier = identifier;
    }
    return self;
}

@end

@implementation FTRUMResourceDataModel
@end
@implementation FTRUMErrorData
@end
@implementation FTRUMLaunchDataModel
-(instancetype)initWithDuration:(NSNumber *)duration{
    self = [super initWithType:FTRUMDataLaunch time:[NSDate date]];
    if (self) {
        self.duration = duration;
    }
    return self;
}
@end

@implementation FTRUMWebViewData

-(instancetype)initWithMeasurement:(NSString *)measurement tm:(long long )tm{
    self = [super initWithType:FTRUMDataWebViewJSBData time:[NSDate date]];
    if (self) {
        self.measurement = measurement;
        self.tm = tm;
    }
    return self;
}

@end
@implementation FTRUMContext
-(instancetype)init{
    self = [super init];
    if (self) {
        self.session_id = [FTBaseInfoHandler randomUUID];
        self.session_type = @"user";
    }
    return self;
}
- (instancetype)copyWithZone:(NSZone *)zone {
    FTRUMContext *context = [[[self class] allocWithZone:zone] init];
    context.action_id = self.action_id;
    context.action_name = self.action_name;
    context.session_id = self.session_id;
    context.session_type = self.session_type;
    context.view_id = self.view_id;
    context.view_referrer = self.view_referrer;
    context.view_name = self.view_name;
    context.sampled_for_error_session = self.sampled_for_error_session;
    context.session_error_timestamp = self.session_error_timestamp;
    return context;
}
-(NSDictionary *)getGlobalSessionViewTags{
    NSMutableDictionary *dict = [NSMutableDictionary new];
    [dict setValue:self.session_id forKey:FT_RUM_KEY_SESSION_ID];
    [dict setValue:self.session_type forKey:FT_RUM_KEY_SESSION_TYPE];
    [dict setValue:self.view_id forKey:FT_KEY_VIEW_ID];
    if(self.view_referrer.length>0){
        [dict setValue:self.view_referrer forKey:FT_KEY_VIEW_REFERRER];
    }
    [dict setValue:self.view_name forKey:FT_KEY_VIEW_NAME];
    return dict;
}
-(NSDictionary *)getGlobalSessionViewActionTags{
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:[self getGlobalSessionViewTags]];
    [dict setValue:self.action_id forKey:FT_KEY_ACTION_ID];
    [dict setValue:self.action_name forKey:FT_KEY_ACTION_NAME];
    return dict;
}
-(NSDictionary *)getGlobalSessionTags{
    return @{FT_RUM_KEY_SESSION_ID:self.session_id,
             FT_RUM_KEY_SESSION_TYPE:self.session_type
    };
}
@end

