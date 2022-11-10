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
@property (nonatomic, strong) NSDictionary *actionProperty;//添加到field中
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
        self.context = [context copy];
        self.actionProperty = model.fields;
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
        case FTRUMDataResourceComplete:
            self.actionResourcesCount += 1;
            self.activeResourcesCount -= 1;
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

    NSDictionary *actiontags = @{FT_RUM_KEY_ACTION_ID:self.action_id,
                                 FT_RUM_KEY_ACTION_NAME:self.action_name,
                                 FT_RUM_KEY_ACTION_TYPE:self.action_type
    };
    NSMutableDictionary *fields = @{FT_DURATION:self.duration,
                             FT_RUM_KEY_ACTION_LONG_TASK_COUNT:@(self.actionLongTaskCount),
                             FT_RUM_KEY_ACTION_RESOURCE_COUNT:@(self.actionResourcesCount),
                             FT_RUM_KEY_ACTION_ERROR_COUNT:@(self.actionErrorCount),
    }.mutableCopy;
    if(self.actionProperty && self.actionProperty.allKeys.count>0){
        [fields addEntriesFromDictionary:self.actionProperty];
    }
    NSMutableDictionary *tags = [NSMutableDictionary dictionaryWithDictionary:sessionViewTag];
    [tags addEntriesFromDictionary:actiontags];
    [[FTMobileAgent sharedInstance] rumWrite:FT_MEASUREMENT_RUM_ACTION terminal:FT_TERMINAL_APP tags:tags fields:fields tm:[FTDateUtil dateTimeNanosecond:self.actionStartTime]];
    if (self.handler) {
        self.handler();
    }
}
@end
