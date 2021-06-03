//
//  FTRUMActionHandler.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/5/21.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTRUMActionHandler.h"
#import "NSDate+FTAdd.h"
#import "FTMobileAgent+Private.h"
#import "FTConstants.h"
#import "FTRUMViewHandler.h"
#import "FTBaseInfoHander.h"

static const NSTimeInterval actionMaxDuration = 10; // 10 seconds

@interface FTRUMActionHandler ()<FTRUMSessionProtocol>
@property (nonatomic, strong,readwrite) FTRUMDataModel *model;
@property (nonatomic, weak) FTRUMViewHandler *parent;
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

-(instancetype)initWithModel:(FTRUMDataModel *)model parent:(FTRUMViewHandler *)parent{
    self = [super init];
    if (self) {
        self.assistant = self;
        self.actionStartTime = model.time;
        self.model = model;
        self.parent = parent;
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
            self.activeResourcesCount -= 1;
            self.actionResourcesCount += 1;
            break;
        case FTRUMDataResourceError:
            self.activeResourcesCount -= 1;
            self.actionErrorCount += 1;
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
    self.duration =  [endDate timeIntervalSinceDate:self.actionStartTime] >= actionMaxDuration?@(actionMaxDuration*1000000000):[endDate ft_nanotimeIntervalSinceDate:self.actionStartTime];

    NSDictionary *sessionTag = @{@"session_id":self.model.baseSessionData.session_id,
                                 @"session_type":self.model.baseSessionData.session_type,
    };
    NSDictionary *viewTag = self.model.baseViewData?@{@"view_id":self.model.baseViewData.view_id,
                                                        @"view_name":self.model.baseViewData.view_name,
                                                        @"view_referrer":self.model.baseViewData.view_referrer,
    }:@{};
    NSDictionary *actiontags = @{@"action_id":self.model.baseActionData.action_id,
                           @"action_name":self.model.baseActionData.action_name,
                           @"action_type":self.model.baseActionData.action_type
    };
    NSDictionary *fields = @{@"duration":self.duration,
                             @"action_long_task_count":[NSNumber numberWithInteger:self.actionLongTaskCount],
                             @"action_resource_count":[NSNumber numberWithInteger:self.actionResourcesCount],
                             @"action_error_count":[NSNumber numberWithInteger:self.actionErrorCount],
    };
    NSMutableDictionary *tags = [NSMutableDictionary dictionaryWithDictionary:sessionTag];
    [tags addEntriesFromDictionary:viewTag];
    [tags addEntriesFromDictionary:actiontags];
    [[FTMobileAgent sharedInstance] rumWrite:FT_TYPE_ACTION terminal:@"app" tags:tags fields:fields];
    if (self.handler) {
        self.handler();
    }
}
@end
