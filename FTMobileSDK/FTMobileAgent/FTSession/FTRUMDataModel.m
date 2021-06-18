//
//  FTRUMDataModel.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/5/25.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTRUMDataModel.h"
#import "FTBaseInfoHander.h"

@implementation FTRUMSessionModel

-(instancetype)initWithSessionID:(NSString *)sessionid{
    self = [super init];
    if (self) {
        self.session_id = sessionid;
        self.session_type = @"user";
    }
    return  self;
}

@end
@implementation FTRUMDataModel
-(instancetype)initWithType:(FTRUMDataType)type time:(NSDate *)time{
    self = [super init];
    if (self) {
        self.time = time;
        self.type = type;
    }
    return self;
}
-(NSDictionary *)getGlobalSessionViewTags{
    NSDictionary *sessionTag = @{@"session_id":self.baseSessionData.session_id,
                                 @"session_type":self.baseSessionData.session_type,
    };
    NSDictionary *viewTag = self.baseViewData?@{@"view_id":self.baseViewData.view_id,
                                                @"view_name":self.baseViewData.view_name,
                                                @"view_referrer":self.baseViewData.view_referrer,
    }:@{};
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:sessionTag];
    [dict addEntriesFromDictionary:viewTag];
    return dict;
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

-(instancetype)initWithActionID:(NSString *)actionid actionName:(NSString *)actionName actionType:(nonnull NSString *)actionType{
    self = [super init];
    if (self) {
        self.action_id = actionid;
        self.action_name = actionName;
        self.action_type = actionType;
    }
    return self;
}
-(NSDictionary *)getActionTags{
    return @{@"action_id":self.action_id,
             @"action_name":self.action_name,
             @"action_type":self.action_type
    };
}
@end
@implementation FTRUMResourceDataModel

-(instancetype)initWithType:(FTRUMDataType)type identifier:(NSString *)identifier{
    self = [super initWithType:type time:[NSDate date]];
    if (self) {
        self.identifier = identifier;
    }
    return self;
}
    
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
