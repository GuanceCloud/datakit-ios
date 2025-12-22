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


