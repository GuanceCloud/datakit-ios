//
//  FTRUMActionScope.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/5/21.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTRUMActionScope.h"
#import "NSDate+FTAdd.h"

static const NSTimeInterval discreteActionTimeoutDuration = 0.1; // 100 milliseconds
/// Maximum duration of a continuous User Action. If it gets exceeded, a new session is started.
static const NSTimeInterval continuousActionMaxDuration = 10; // 10 seconds

@interface FTRUMActionScope ()<FTRUMScopeProtocol>
//field
@property (nonatomic, strong) NSDate *actionStartTime;
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
@property (nonatomic, assign) BOOL isActive;
@property (nonatomic, strong) NSMutableArray *sourceArray;
@property (nonatomic, assign) NSInteger activeLoading;
@end
@implementation FTRUMActionScope

-(instancetype)init{
    self = [super init];
    if (self) {
        self.assistant = self;
        self.startDate = [NSDate date];
        self.isActive = YES;
    }
    return  self;
}
-(void)end{
    
    self.duration = [[NSDate date] ft_nanotimeIntervalSinceDate:self.actionStartTime];
    NSDictionary *tags = @{@"actionid":self.actionid,
                           @"actionName":self.actionName,
                           @"actionType":self.actionType
    };
    NSDictionary *fields = @{@"duration":self.duration,
                             @"action_long_task_count":[NSNumber numberWithInteger:self.actionLongTaskCount],
                             @"action_resources_count":[NSNumber numberWithInteger:self.actionResourcesCount],
                             @"action_error_count":[NSNumber numberWithInteger:self.actionErrorCount],
    };
    
}
- (BOOL)process:(NSDictionary *)commond{
    
    return NO;
}



-(BOOL)timedOutOrExpired:(NSDate*)currentTime{
    NSTimeInterval timeElapsedSinceStartTime = [currentTime timeIntervalSinceDate:_actionStartTime];
    BOOL timedOut = timeElapsedSinceStartTime >= discreteActionTimeoutDuration;

    NSTimeInterval sessionDuration = [currentTime  timeIntervalSinceDate:_actionStartTime];
    BOOL expired = sessionDuration >= continuousActionMaxDuration;

    return timedOut || expired;
}

@end
