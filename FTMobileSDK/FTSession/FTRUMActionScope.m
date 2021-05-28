//
//  FTRUMActionScope.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/5/21.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTRUMActionScope.h"
#import "NSDate+FTAdd.h"
#import "FTMobileAgent+Private.h"
#import "FTConstants.h"
#import "FTRUMViewScope.h"
static const NSTimeInterval discreteActionTimeoutDuration = 0.1; // 100 milliseconds
/// Maximum duration of a continuous User Action. If it gets exceeded, a new session is started.
static const NSTimeInterval continuousActionMaxDuration = 10; // 10 seconds

@interface FTRUMActionScope ()<FTRUMScopeProtocol>
@property (nonatomic, strong,readwrite) FTRUMCommand *command;
@property (nonatomic, weak) FTRUMViewScope *parent;
//field
@property (nonatomic, strong) NSDate *actionStartTime;
@property (nonatomic, strong) NSDate *lastActivityTime;
@property (nonatomic, strong) NSNumber *duration;
@property (nonatomic, assign) NSInteger actionLongTaskCount;
@property (nonatomic, assign) NSInteger actionResourcesCount;
@property (nonatomic, assign) NSInteger actionErrorCount;
//tag
@property (nonatomic, copy) NSString *actionid;
@property (nonatomic, copy) NSString *actionName;
@property (nonatomic, copy) NSString *actionType;

//private
@property (nonatomic, strong) NSDate *startDate;
@property (nonatomic, strong) NSMutableArray *sourceArray;
@property (nonatomic, assign) NSInteger activeResourcesCount;
@end
@implementation FTRUMActionScope

-(instancetype)initWithCommand:(FTRUMCommand *)command parent:(FTRUMViewScope *)parent{
    self = [super init];
    if (self) {
        self.assistant = self;
        self.actionStartTime = command.time;
        self.command = command;
        self.lastActivityTime = command.time;
        self.parent = parent;
    }
    return  self;
}
- (BOOL)process:(FTRUMCommand *)command{
    if ([self timedOutOrExpired:command.time]&&[self allResourcesCompletedLoading]){
        [self writeActionData];
        return NO;
    }
    self.lastActivityTime = command.time;
    
    switch (command.type) {
        case FTRUMDataViewStop:
            
            break;
        case FTRUMDataViewError:
            self.actionErrorCount++;
            break;
        case FTRUMDataViewResourceStart:
            self.activeResourcesCount += 1;
            break;
        case FTRUMDataViewResourceSuccess:
            self.activeResourcesCount -= 1;
            self.actionResourcesCount += 1;
            break;
        case FTRUMDataViewResourceError:
            self.activeResourcesCount -= 1;
            self.actionErrorCount += 1;
            break;
        case FTRUMDataViewLongTask:
            self.actionLongTaskCount++;
            break;
        default:
            break;
    }
    return YES;
}

-(BOOL)timedOutOrExpired:(NSDate*)currentTime{
    NSTimeInterval timeElapsedSinceStartTime = [currentTime timeIntervalSinceDate:_actionStartTime];
    BOOL timedOut = timeElapsedSinceStartTime >= discreteActionTimeoutDuration;
    
    NSTimeInterval sessionDuration = [currentTime  timeIntervalSinceDate:_actionStartTime];
    BOOL expired = sessionDuration >= continuousActionMaxDuration;
    
    return timedOut || expired;
}

-(BOOL)allResourcesCompletedLoading{
    return self.activeResourcesCount<=0;
}
-(void)writeActionData{
    self.duration = [self.lastActivityTime ft_nanotimeIntervalSinceDate:self.actionStartTime];
    NSDictionary *sessionTag = @{@"session_id":self.command.baseSessionData.session_id,
                                 @"session_type":self.command.baseSessionData.session_type,
    };
    //
    NSDictionary *viewTag = self.command.baseViewData?@{@"view_id":self.command.baseViewData.view_id,
                                                        @"view_name":self.command.baseViewData.view_name,
                                                        @"view_referrer":self.command.baseViewData.view_referrer,
                                                        @"is_active":@(self.parent.isActiveView),
    }:@{};
    NSDictionary *actiontags = @{@"action_id":self.command.baseActionData.action_id,
                           @"action_name":self.command.baseActionData.action_name,
                           @"action_type":self.command.baseActionData.action_type
    };
    NSDictionary *fields = @{@"duration":self.duration,
                             @"action_long_task_count":[NSNumber numberWithInteger:self.actionLongTaskCount],
                             @"action_resources_count":[NSNumber numberWithInteger:self.actionResourcesCount],
                             @"action_error_count":[NSNumber numberWithInteger:self.actionErrorCount],
    };
    NSMutableDictionary *tags = [NSMutableDictionary dictionaryWithDictionary:sessionTag];
    [tags addEntriesFromDictionary:viewTag];
    [tags addEntriesFromDictionary:actiontags];
    [[FTMobileAgent sharedInstance] rumTrackES:FT_TYPE_ACTION terminal:@"app" tags:tags fields:fields];
    if (self.handler) {
        self.handler();
    }
}
@end
