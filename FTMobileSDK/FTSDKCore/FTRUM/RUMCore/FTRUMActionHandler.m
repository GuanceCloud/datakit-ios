//
//  FTRUMActionHandler.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/5/21.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTRUMActionHandler.h"
#import "NSDate+FTUtil.h"
#import "FTConstants.h"
#import "FTBaseInfoHandler.h"
static const NSTimeInterval actionMaxDuration = 5; // 5 seconds
static const NSTimeInterval discreteActionTimeoutDuration = 0.1;
@interface FTRUMActionHandler ()<FTRUMSessionProtocol>
@property (nonatomic, strong) FTRUMDependencies *dependencies;
@property (nonatomic, assign) FTRUMDataType type;
@property (nonatomic, strong) FTRUMContext *context;
@property (nonatomic, copy) NSString *action_name;
@property (nonatomic, copy) NSString *action_type;
@property (nonatomic, copy) NSString *action_id;
//field
@property (nonatomic, strong) NSDate *actionStartTime;
@property (nonatomic, assign) NSInteger actionLongTaskCount;
@property (nonatomic, assign) NSInteger actionResourcesCount;
@property (nonatomic, assign) NSInteger actionErrorCount;
@property (nonatomic, strong) NSDictionary *actionProperty;//添加到field中
//private
@property (nonatomic, assign) NSInteger activeResourcesCount;
@property (nonatomic, strong) NSDate *lastResourceEndDate;
@end
@implementation FTRUMActionHandler

-(instancetype)initWithModel:(FTRUMActionModel *)model context:(FTRUMContext *)context dependencies:(nonnull FTRUMDependencies *)dependencies{
    self = [super init];
    if (self) {
        self.dependencies = dependencies;
        self.assistant = self;
        self.actionStartTime = model.time;
        self.action_id = [FTBaseInfoHandler randomUUID];
        self.action_name = model.action_name;
        self.action_type = model.action_type;
        self.type = model.type;
        context.action_id = self.action_id;
        context.action_name = self.action_name;
        self.context = context;
        self.actionProperty = model.fields;
        self.context.action_id = self.action_id;
    }
    return  self;
}
- (BOOL)process:(FTRUMDataModel *)model context:(nonnull NSDictionary *)context{
    NSDate *timedOutDate = [self timedOutOrExpired:model.time];
    if(timedOutDate && [self allResourcesCompletedLoading]){
        [self writeActionData:timedOutDate context:context];
        return NO;
    }
    NSDate *maxDuration = [self timedOutMaxDuration:model.time];
    if (maxDuration) {
        [self writeActionData:maxDuration context:context];
        return NO;
    }
    switch (model.type) {
        case FTRUMDataViewStart:
        case FTRUMDataViewStop:
        case FTRUMDataStopAction:
            [self writeActionData:model.time context:context];
            return NO;
            break;
        case FTRUMDataError:{
            self.actionErrorCount++;
            FTRUMErrorData *error = (FTRUMErrorData *)model;
            if(error.fatal){
                [self writeActionData:model.time context:context];
                return NO;
            }
        }
            break;
        case FTRUMDataResourceStart:
            self.activeResourcesCount += 1;
            break;
        case FTRUMDataResourceComplete:
            self.actionResourcesCount += 1;
            self.activeResourcesCount -= 1;
            self.lastResourceEndDate = model.time;
            break;
        case FTRUMDataLongTask:
            self.actionLongTaskCount++;
            break;
        case FTRUMDataResourceError:
            self.actionErrorCount++;
            break;
        default:
            break;
    }
    return YES;
}

-(NSDate *)timedOutOrExpired:(NSDate*)currentTime{
    if(self.lastResourceEndDate){
        NSTimeInterval duration = [self.lastResourceEndDate timeIntervalSinceDate:_actionStartTime];
        BOOL expired = duration >= discreteActionTimeoutDuration;
        if(expired){
            return self.lastResourceEndDate;
        }
    }
    NSTimeInterval actionDuration = [currentTime  timeIntervalSinceDate:_actionStartTime];
    BOOL expired = actionDuration >= discreteActionTimeoutDuration;
    if(expired){
        return [_actionStartTime dateByAddingTimeInterval:discreteActionTimeoutDuration];
    }
    return  nil;
}
-(NSDate *)timedOutMaxDuration:(NSDate *)currentTime{
    NSTimeInterval actionDuration = [currentTime  timeIntervalSinceDate:_actionStartTime];
    BOOL expired = actionDuration >= actionMaxDuration;
    if(expired){
        return [_actionStartTime dateByAddingTimeInterval:actionMaxDuration];
    }
    return  nil;
}
-(BOOL)allResourcesCompletedLoading{
    return self.activeResourcesCount<=0;
}
-(void)writeActionData:(NSDate *)endDate context:(NSDictionary *)context{
    NSNumber *duration =  [endDate timeIntervalSinceDate:self.actionStartTime] >= actionMaxDuration?@(actionMaxDuration*1000000000):[self.actionStartTime ft_nanosecondTimeIntervalToDate:endDate];
    NSDictionary *sessionViewActionTag = [self.context getGlobalSessionViewActionTags];
    
    NSMutableDictionary *fields = [NSMutableDictionary dictionary];
    [fields setValue:duration forKey:FT_DURATION];
    [fields setValue:@(self.actionLongTaskCount) forKey:FT_KEY_ACTION_LONG_TASK_COUNT];
    [fields setValue:@(self.actionResourcesCount) forKey:FT_KEY_ACTION_RESOURCE_COUNT];
    [fields setValue:@(self.actionErrorCount) forKey:FT_KEY_ACTION_ERROR_COUNT];
    if(self.actionProperty && self.actionProperty.allKeys.count>0){
        [fields addEntriesFromDictionary:self.actionProperty];
    }
    NSMutableDictionary *tags = [NSMutableDictionary dictionaryWithDictionary:context];
    [tags addEntriesFromDictionary:sessionViewActionTag];
    [tags setValue:self.action_type forKey:FT_KEY_ACTION_TYPE];
    [self.dependencies.writer rumWrite:FT_RUM_SOURCE_ACTION tags:tags fields:fields time:[self.actionStartTime ft_nanosecondTimeStamp]];
    if (self.handler) {
        self.handler();
    }
}
@end
