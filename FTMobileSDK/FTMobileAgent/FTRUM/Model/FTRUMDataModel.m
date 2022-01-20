//
//  FTRUMDataModel.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/5/25.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTRUMDataModel.h"
#import "FTConstants.h"
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
-(void)setTime:(NSDate *)time{
    if (!time) {
        _time = [NSDate date];
    }else{
        _time = time;
    }
}
@end
@implementation FTRUMViewModel
-(instancetype)initWithViewID:(NSString *)viewid viewName:(NSString *)viewName viewReferrer:(NSString *)viewReferrer{
    self = [super init];
    if (self) {
        self.view_id = viewid;
        self.view_name = viewName;
        self.view_referrer = viewReferrer;
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

@implementation FTRUMLaunchDataModel
-(instancetype)initWithType:(FTRUMDataType)type duration:(NSNumber *)duration{
    self = [super initWithType:type time:[NSDate date]];
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
        self.session_id = [NSUUID UUID].UUIDString;
        self.session_type = @"user";
    }
    return self;
}
- (instancetype)copyWithZone:(NSZone *)zone {
    FTRUMContext *context = [[[self class] allocWithZone:zone] init];
    context.action_id = self.action_id;
    context.session_id = self.session_id;
    context.session_type = self.session_type;
    context.view_id = self.view_id;
    context.view_referrer = self.view_referrer;
    context.view_name = self.view_name;
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
    [dict setValue:self.action_id forKey:FT_RUM_KEY_ACTION_ID];
    return dict;
}
@end

