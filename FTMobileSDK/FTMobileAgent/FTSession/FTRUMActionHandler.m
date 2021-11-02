//
//  FTRUMActionHandler.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/5/21.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTRUMActionHandler.h"
#import "FTDateUtil.h"
#import "FTMobileAgent+Private.h"
#import "FTConstants.h"

static const NSTimeInterval actionMaxDuration = 10; // 10 seconds

@interface FTRUMActionHandler ()<FTRUMSessionProtocol>
@property (nonatomic, assign) FTRUMDataType type;
@property (nonatomic, strong) FTRUMContext *context;
@property (nonatomic, copy) NSString *action_name;
@property (nonatomic, copy) NSString *action_type;
@property (nonatomic, copy) NSString *action_id;
//field
@property (nonatomic, strong) NSDate *actionStartTime;
@property (nonatomic, strong) NSNumber *duration;
@property (nonatomic, assign) NSInteger actionLongTaskCount;
@property (nonatomic, assign) NSInteger actionResourcesCount;
@property (nonatomic, assign) NSInteger actionErrorCount;

//private
@property (nonatomic, assign) NSInteger activeResourcesCount;
@end
@implementation FTRUMActionHandler

-(instancetype)initWithModel:(FTRUMActionModel *)model context:(FTRUMContext *)context{
    self = [super init];
    if (self) {
        self.assistant = self;
        self.actionStartTime = model.time;
        self.action_id = [NSUUID UUID].UUIDString;
        self.action_name = model.action_name;
        self.action_type = model.action_type;
        self.type = model.type;
        if ([model isKindOfClass:FTRUMLaunchDataModel.class]) {
            FTRUMLaunchDataModel *launchModel = (FTRUMLaunchDataModel*)model;
            self.duration =launchModel.duration;
        }
        self.context = [context copy];
        self.context.action_id = self.action_id;
    }
    return  self;
}
- (BOOL)process:(FTRUMDataModel *)model{
   
    if ([self timedOutOrExpired:model.time]&&[self allResourcesCompletedLoading]){
        [self writeActionData:model.time];
        return NO;
    }
    if (model.type ==  FTRUMDataLaunchHot|| model.type == FTRUMDataLaunchCold||
        model.type == FTRUMDataClick) {
        if ([self allResourcesCompletedLoading]) {
            [self writeActionData:model.time];
            return NO;
        }
    }
    switch (model.type) {
        case FTRUMDataError:
            self.actionErrorCount++;
            break;
        case FTRUMDataResourceStart:
            self.activeResourcesCount += 1;
            break;
        case FTRUMDataResourceSuccess:
            self.actionResourcesCount += 1;
            break;
        case FTRUMDataResourceError:
            self.actionErrorCount += 1;
            break;
        case FTRUMDataResourceStop:
            self.activeResourcesCount -= 1;
            break;
        case FTRUMDataLongTask:
            self.actionLongTaskCount++;
            break;
        default:
            break;
    }
    return YES;
}

-(BOOL)timedOutOrExpired:(NSDate*)currentTime{
    NSTimeInterval sessionDuration = [currentTime  timeIntervalSinceDate:_actionStartTime];
    BOOL expired = sessionDuration >= actionMaxDuration;
    return  expired;
}

-(BOOL)allResourcesCompletedLoading{
    return self.activeResourcesCount<=0;
}
-(void)writeActionData:(NSDate *)endDate{
    if (self.type == FTRUMDataClick) {
        self.duration =  [endDate timeIntervalSinceDate:self.actionStartTime] >= actionMaxDuration?@(actionMaxDuration*1000000000):[FTDateUtil nanosecondTimeIntervalSinceDate:self.actionStartTime toDate:endDate];
    }
    NSDictionary *sessionViewTag = [self.context getGlobalSessionViewTags];

    NSDictionary *actiontags = @{@"action_id":self.action_id,
                                 @"action_name":self.action_name,
                                 @"action_type":self.action_type
    };
    NSDictionary *fields = @{@"duration":self.duration,
                             @"action_long_task_count":@(self.actionLongTaskCount),
                             @"action_resource_count":@(self.actionResourcesCount),
                             @"action_error_count":@(self.actionErrorCount),
    };
    NSMutableDictionary *tags = [NSMutableDictionary dictionaryWithDictionary:sessionViewTag];
    [tags addEntriesFromDictionary:actiontags];
    [[FTMobileAgent sharedInstance] rumWrite:FT_TYPE_ACTION terminal:@"app" tags:tags fields:fields tm:[FTDateUtil dateTimeNanosecond:self.actionStartTime]];
    if (self.handler) {
        self.handler();
    }
}
@end
