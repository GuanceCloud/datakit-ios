//
//  FTRUMViewHandler.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/5/24.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTRUMViewHandler.h"
#import "FTRUMActionHandler.h"
#import "FTRUMResourceHandler.h"
#import "FTConstants.h"
#import "NSDate+FTUtil.h"
#import "FTBaseInfoHandler.h"
#import "FTMonitorItem.h"
#import "FTMonitorValue.h"
#import "FTLog+Private.h"
#import "FTRUMMonitor.h"

@interface FTRUMViewHandler()<FTRUMSessionProtocol>
@property (nonatomic, strong) FTRUMDependencies *rumDependencies;
@property (nonatomic, strong) FTRUMContext *context;
@property (nonatomic, strong) FTRUMActionHandler *actionHandler;
@property (nonatomic, assign) BOOL isInitialView;
@property (nonatomic, strong) NSMutableDictionary *resourceHandlers;
@property (nonatomic, assign) NSInteger viewLongTaskCount;
@property (nonatomic, assign) NSInteger viewResourceCount;
@property (nonatomic, assign) NSInteger viewErrorCount;
@property (nonatomic, assign) NSInteger viewActionCount;
@property (nonatomic, assign) BOOL didReceiveStartData;
@property (nonatomic, strong) NSDate *viewStartTime;
@property (nonatomic, assign) BOOL needUpdateView;
@property (nonatomic, strong) FTMonitorItem *monitorItem;
@property (nonatomic, strong) NSMutableDictionary *viewProperty;//存储在field中
@property (nonatomic, assign) uint64_t updateTime;
@end
@implementation FTRUMViewHandler
-(instancetype)initWithModel:(FTRUMViewModel *)model context:(nonnull FTRUMContext *)context rumDependencies:(FTRUMDependencies *)rumDependencies{
    self = [super init];
    if (self) {
        self.assistant = self;
        self.isActiveView = YES;
        self.isInitialView = model.isInitialView;
        self.updateTime = 0;
        self.view_id = model.view_id;
        self.view_name = model.view_name;
        self.view_referrer = model.view_referrer;
        self.loading_time = model.loading_time;
        self.didReceiveStartData = NO;
        self.viewStartTime = model.time;
        self.resourceHandlers = [NSMutableDictionary new];
        self.viewProperty = [NSMutableDictionary new];
        self.rumDependencies = rumDependencies;
        if(model.fields && model.fields.allKeys.count>0){
            [self.viewProperty addEntriesFromDictionary:model.fields];
        }
        _context = [context copy];
        _context.view_name = self.view_name;
        _context.view_id = self.view_id;
        _context.view_referrer = self.view_referrer;
        self.monitorItem = [[FTMonitorItem alloc]initWithCpuMonitor:rumDependencies.monitor.cpuMonitor memoryMonitor:rumDependencies.monitor.memoryMonitor displayRateMonitor:rumDependencies.monitor.displayMonitor frequency:rumDependencies.monitor.frequency];
    }
    return self;
}
- (BOOL)process:(FTRUMDataModel *)model context:(nonnull NSDictionary *)context{
   
    self.needUpdateView = NO;
    self.actionHandler =(FTRUMActionHandler *)[self.assistant manage:(FTRUMHandler *)self.actionHandler byPropagatingData:model context:context];
    switch (model.type) {
        case FTRUMDataViewStart:{
            FTRUMViewModel *viewModel = (FTRUMViewModel *)model;
            if (self.view_id && [self.view_id isEqualToString:viewModel.view_id]) {
                if (self.didReceiveStartData ) {
                    self.isActiveView = NO;
                }
                self.didReceiveStartData = YES;
                self.needUpdateView = YES;
            }else if(self.isActiveView == YES){
                self.isActiveView = NO;
                self.needUpdateView = YES;
            }
        }
            break;
        case FTRUMDataViewStop:{
            FTRUMViewModel *viewModel = (FTRUMViewModel *)model;
            if (self.view_id && [self.view_id isEqualToString:viewModel.view_id]) {
                self.needUpdateView = YES;
                self.isActiveView = NO;
                if(viewModel.fields && viewModel.fields.allKeys.count>0){
                    [self.viewProperty addEntriesFromDictionary:viewModel.fields];
                }
            }
        }
            break;
        case FTRUMDataStartAction:
            if (self.isActiveView && self.actionHandler == nil) {
                [self startAction:model];
            }else{
                FTInnerLogDebug(@"RUM Action %@ was dropped, because another action is still active for the same view.",((FTRUMActionModel *)model).action_name);
            }
            break;
        case FTRUMDataAddAction:
            [self addAction:model context:context];
            break;
        case FTRUMDataError:
            if (self.isActiveView) {
                FTRUMErrorData *error = (FTRUMErrorData *)model;
                if(error.fatal){
                    self.isActiveView = NO;
                }
                self.viewErrorCount++;
                self.needUpdateView = YES;
                [self writeErrorData:model context:context];
            }
            break;
        case FTRUMDataResourceStart:
            if (self.isActiveView) {
                [self startResource:(FTRUMResourceDataModel *)model];
            }
            break;
        case FTRUMDataLongTask:
            if (self.isActiveView) {
                self.viewLongTaskCount++;
                self.needUpdateView = YES;
                [self writeErrorData:model context:context];
            }
            break;
        default:
            break;
    }
    if ([model isKindOfClass:FTRUMResourceModel.class]) {
        FTRUMResourceDataModel *newModel = (FTRUMResourceDataModel *)model;
        FTRUMResourceHandler *handler =  self.resourceHandlers[newModel.identifier];
        self.resourceHandlers[newModel.identifier] =[handler.assistant manage:handler byPropagatingData:model context:context];
    }
    
    BOOL hasNoPendingResources = self.resourceHandlers.count == 0;
    BOOL shouldComplete = !self.isActiveView && hasNoPendingResources;
    if (shouldComplete) {
        [self.actionHandler writeActionData:[NSDate date] context:context];
    }
    if (self.needUpdateView) {
        [self writeViewData:model context:context];
    }
    return !shouldComplete;
}
- (void)startAction:(FTRUMDataModel *)model{
    __weak typeof(self) weakSelf = self;
    FTRUMActionHandler *actionHandler = [[FTRUMActionHandler alloc]initWithModel:(FTRUMActionModel *)model context:self.context dependencies:self.rumDependencies];
    actionHandler.handler = ^{
        weakSelf.viewActionCount +=1;
        weakSelf.needUpdateView = YES;
        weakSelf.context.action_id = nil;
        weakSelf.context.action_name = nil;
    };
    self.actionHandler = actionHandler;
}
- (void)addAction:(FTRUMDataModel *)model context:(NSDictionary *)context{
    __weak typeof(self) weakSelf = self;
    FTRUMActionHandler *actionHandler = [[FTRUMActionHandler alloc]initWithModel:(FTRUMActionModel *)model context:self.context dependencies:self.rumDependencies];
    model.type = FTRUMDataStopAction;
    actionHandler.handler = ^{
        weakSelf.viewActionCount +=1;
        weakSelf.needUpdateView = YES;
    };
    [actionHandler.assistant process:model context:context];
}
- (void)startResource:(FTRUMResourceDataModel *)model{
    __weak typeof(self) weakSelf = self;
    FTRUMResourceHandler *resourceHandler = [[FTRUMResourceHandler alloc] initWithModel:model context:self.context dependencies:self.rumDependencies];
    resourceHandler.resourceHandler = ^(BOOL add){
        if(add){
            weakSelf.viewResourceCount+=1;
            weakSelf.needUpdateView = YES;
        }
    };
    resourceHandler.errorHandler = ^{
        weakSelf.viewErrorCount+=1;
    };
    self.resourceHandlers[model.identifier] =resourceHandler;
}
- (void)writeErrorData:(FTRUMDataModel *)model context:(NSDictionary *)context{
    NSDictionary *sessionViewTag = [self.context getGlobalSessionViewActionTags];
    NSMutableDictionary *tags = [NSMutableDictionary dictionaryWithDictionary:context];
    [tags addEntriesFromDictionary:sessionViewTag];
    [tags addEntriesFromDictionary:model.tags];
    NSMutableDictionary *fields = [NSMutableDictionary dictionaryWithDictionary:model.fields];
    [fields setValue:@(self.rumDependencies.sessionHasReplay) forKey:FT_SESSION_HAS_REPLAY];
    NSString *error = model.type == FTRUMDataLongTask?FT_RUM_SOURCE_LONG_TASK :FT_RUM_SOURCE_ERROR;
    [self.rumDependencies.writer rumWrite:error tags:tags fields:fields time:model.tm];
    if(self.errorHandled){
        self.errorHandled();
    }
}
- (void)writeViewData:(FTRUMDataModel *)model context:(NSDictionary *)context{
    if(self.isInitialView){
        return;
    }
    self.updateTime+=1;
    //秒级
    NSTimeInterval sTimeSpent = MAX(1e-9, [model.time timeIntervalSinceDate:self.viewStartTime]);
    //纳秒级
    NSNumber *nTimeSpent = [NSNumber numberWithLongLong:sTimeSpent * 1000000000];

    NSMutableDictionary *tags = [NSMutableDictionary dictionaryWithDictionary:context];
    [tags addEntriesFromDictionary:[self.context getGlobalSessionViewTags]];
    FTMonitorValue *cpu = self.monitorItem.cpu;
    FTMonitorValue *memory = self.monitorItem.memory;
    FTMonitorValue *refreshRateInfo = self.monitorItem.refreshDisplay;
    NSMutableDictionary *fields = @{FT_KEY_VIEW_ERROR_COUNT:@(self.viewErrorCount),
                                   FT_KEY_VIEW_RESOURCE_COUNT:@(self.viewResourceCount),
                                   FT_KEY_VIEW_LONG_TASK_COUNT:@(self.viewLongTaskCount),
                                   FT_KEY_VIEW_ACTION_COUNT:@(self.viewActionCount),
                                   FT_KEY_TIME_SPENT:nTimeSpent,
                                   FT_KEY_VIEW_UPDATE_TIME:@(self.updateTime),
                                   FT_KEY_IS_ACTIVE:[NSNumber numberWithBool:self.isActiveView],
    }.mutableCopy;
    if(self.viewProperty && self.viewProperty.allKeys.count>0){
        [fields addEntriesFromDictionary:self.viewProperty];
    }
    if (cpu && cpu.greatestDiff>0) {
        [fields setValue:@(cpu.greatestDiff) forKey:FT_CPU_TICK_COUNT];
        if(sTimeSpent>1.0){
            [fields setValue:@(cpu.greatestDiff/sTimeSpent) forKey:FT_CPU_TICK_COUNT_PER_SECOND];
        }
    }
    if (memory && memory.maxValue>0) {
        [fields setValue:@(memory.meanValue) forKey:FT_MEMORY_AVG];
        [fields setValue:@(memory.maxValue) forKey:FT_MEMORY_MAX];
    }
    if (refreshRateInfo && refreshRateInfo.minValue>0) {
        [fields setValue:@(refreshRateInfo.minValue) forKey:FT_FPS_MINI];
        [fields setValue:@(refreshRateInfo.meanValue) forKey:FT_FPS_AVG];
    }
    if (![self.loading_time isEqual:@0]) {
        [fields setValue:self.loading_time forKey:FT_KEY_LOADING_TIME];
    }
    // session-replay
    [fields setValue:@(self.rumDependencies.sessionHasReplay) forKey:FT_SESSION_HAS_REPLAY];
    NSDictionary *dict = [self.rumDependencies.sessionReplayStats valueForKey:self.view_id];
    if(dict){
        [fields setValue:dict forKey:FT_SESSION_REPLAY_STATS];
    }
    long long time = [self.viewStartTime ft_nanosecondTimeStamp];
    [self.rumDependencies.writer rumWrite:FT_RUM_SOURCE_VIEW tags:tags fields:fields time:time];
    self.rumDependencies.fatalErrorContext.lastViewContext = @{@"tags":tags,
                                                               @"fields":fields,
                                                               @"time":[NSNumber numberWithLongLong:time]
    };
}

@end
