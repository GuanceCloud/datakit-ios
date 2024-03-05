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
#import "FTDateUtil.h"
#import "FTBaseInfoHandler.h"
#import "FTMonitorItem.h"
#import "FTMonitorValue.h"
#import "FTInternalLog.h"
#import "FTRUMMonitor.h"
@interface FTRUMViewHandler()<FTRUMSessionProtocol>
@property (nonatomic, strong) FTRUMContext *context;
@property (nonatomic, strong) FTRUMContext *sessionContext;
@property (nonatomic, strong) FTRUMActionHandler *actionHandler;
@property (nonatomic, strong) NSMutableDictionary *resourceHandlers;
@property (nonatomic, assign) NSInteger viewLongTaskCount;
@property (nonatomic, assign) NSInteger viewResourceCount;
@property (nonatomic, assign) NSInteger viewErrorCount;
@property (nonatomic, assign) NSInteger viewActionCount;
@property (nonatomic, assign) BOOL didReceiveStartData;
@property (nonatomic, strong) NSDate *viewStartTime;
@property (nonatomic, assign) BOOL needUpdateView;
@property (nonatomic, strong) FTRUMMonitor *monitor;
@property (nonatomic, strong) FTMonitorItem *monitorItem;
@property (nonatomic, strong) NSMutableDictionary *viewProperty;//存储在field中
@property (nonatomic, assign) uint64_t updateTime;
@end
@implementation FTRUMViewHandler
-(instancetype)initWithModel:(FTRUMViewModel *)model context:(nonnull FTRUMContext *)context monitor:(FTRUMMonitor *)monitor{
    self = [super init];
    if (self) {
        self.assistant = self;
        self.isActiveView = YES;
        self.updateTime = 0;
        self.view_id = model.view_id;
        self.view_name = model.view_name;
        self.view_referrer = model.view_referrer;
        self.loading_time = model.loading_time;
        self.didReceiveStartData = NO;
        self.viewStartTime = model.time;
        self.resourceHandlers = [NSMutableDictionary new];
        self.viewProperty = [NSMutableDictionary new];
        if(model.fields && model.fields.allKeys.count>0){
            [self.viewProperty addEntriesFromDictionary:model.fields];
        }
        self.sessionContext = context;
        self.monitor = monitor;
        self.monitorItem = [[FTMonitorItem alloc]initWithCpuMonitor:monitor.cpuMonitor memoryMonitor:monitor.memoryMonitor displayRateMonitor:monitor.displayMonitor frequency:monitor.frequency];
    }
    return self;
}
- (FTRUMContext *)context{
    FTRUMContext *context = [self.sessionContext copy];
    context.view_name = self.view_name;
    context.view_id = self.view_id;
    context.view_referrer = self.view_referrer;
    context.writer = self.sessionContext.writer;
    if(self.actionHandler){
        context.action_id = self.actionHandler.context.action_id;
        context.action_name = self.actionHandler.context.action_name;
    }
    return context;
}
- (BOOL)process:(FTRUMDataModel *)model{
   
    self.needUpdateView = NO;
    self.actionHandler =(FTRUMActionHandler *)[self.assistant manage:(FTRUMHandler *)self.actionHandler byPropagatingData:model];
    switch (model.type) {
        case FTRUMDataViewStart:{
            FTRUMViewModel *viewModel = (FTRUMViewModel *)model;
            if (self.view_id && [self.view_id isEqualToString:viewModel.view_id]) {
                if (self.didReceiveStartData ) {
                    self.isActiveView = NO;
                }
                self.didReceiveStartData = YES;
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
        case FTRUMDataClick:
            if (self.isActiveView && self.actionHandler == nil) {
                [self startAction:model];
            }
            break;
        case FTRUMDataError:
            if (self.isActiveView) {
                FTRUMErrorData *error = (FTRUMErrorData *)model;
                if(error.fatal){
                    self.isActiveView = NO;
                }
                self.viewErrorCount++;
                self.needUpdateView = YES;
                [self writeErrorData:model];
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
                [self writeErrorData:model];
            }
            break;
        default:
            break;
    }
    if ([model isKindOfClass:FTRUMResourceModel.class]) {
        FTRUMResourceDataModel *newModel = (FTRUMResourceDataModel *)model;
        FTRUMResourceHandler *handler =  self.resourceHandlers[newModel.identifier];
        self.resourceHandlers[newModel.identifier] =[handler.assistant manage:handler byPropagatingData:model];
    }
    
    BOOL hasNoPendingResources = self.resourceHandlers.count == 0;
    BOOL shouldComplete = !self.isActiveView && hasNoPendingResources;
    if (shouldComplete) {
        [self.actionHandler writeActionData:[NSDate date]];
    }
    if (self.needUpdateView) {
        [self writeViewData:model];
    }
    return !shouldComplete;
}
- (void)startAction:(FTRUMDataModel *)model{
    __weak typeof(self) weakSelf = self;
    FTRUMActionHandler *actionHandler = [[FTRUMActionHandler alloc]initWithModel:(FTRUMActionModel *)model context:self.context];
    actionHandler.handler = ^{
        weakSelf.viewActionCount +=1;
        weakSelf.needUpdateView = YES;
    };
    self.actionHandler = actionHandler;
}
- (void)startResource:(FTRUMResourceDataModel *)model{
    __weak typeof(self) weakSelf = self;
    FTRUMResourceHandler *resourceHandler = [[FTRUMResourceHandler alloc] initWithModel:model context:self.context];
    resourceHandler.resourceHandler = ^{
        weakSelf.viewResourceCount+=1;
        weakSelf.needUpdateView = YES;
    };
    resourceHandler.errorHandler = ^{
        weakSelf.viewErrorCount+=1;
    };
    self.resourceHandlers[model.identifier] =resourceHandler;
}
- (void)writeErrorData:(FTRUMDataModel *)model{
    NSDictionary *sessionViewTag = [self.context getGlobalSessionViewActionTags];
    NSMutableDictionary *tags = [NSMutableDictionary dictionaryWithDictionary:sessionViewTag];
    [tags addEntriesFromDictionary:model.tags];
    NSString *error = model.type == FTRUMDataLongTask?FT_RUM_SOURCE_LONG_TASK :FT_RUM_SOURCE_ERROR;
    [self.context.writer rumWrite:error tags:tags fields:model.fields time:model.tm];
    if(self.errorHandled){
        self.errorHandled();
    }
}
- (void)writeViewData:(FTRUMDataModel *)model{
    self.updateTime+=1;
    //秒级
    NSTimeInterval sTimeSpent = MAX(1e-9, [model.time timeIntervalSinceDate:self.viewStartTime]);
    //纳秒级
    NSNumber *nTimeSpent = [NSNumber numberWithLongLong:sTimeSpent * 1000000000];

    NSMutableDictionary *sessionViewTag = [NSMutableDictionary dictionaryWithDictionary:[self.context getGlobalSessionViewTags]];
    FTMonitorValue *cpu = self.monitorItem.cpu;
    FTMonitorValue *memory = self.monitorItem.memory;
    FTMonitorValue *refreshRateInfo = self.monitorItem.refreshDisplay;
    NSMutableDictionary *field = @{FT_KEY_VIEW_ERROR_COUNT:@(self.viewErrorCount),
                                   FT_KEY_VIEW_RESOURCE_COUNT:@(self.viewResourceCount),
                                   FT_KEY_VIEW_LONG_TASK_COUNT:@(self.viewLongTaskCount),
                                   FT_KEY_VIEW_ACTION_COUNT:@(self.viewActionCount),
                                   FT_KEY_TIME_SPENT:nTimeSpent,
                                   FT_KEY_VIEW_UPDATE_TIME:@(self.updateTime),
                                   FT_KEY_IS_ACTIVE:[NSNumber numberWithBool:self.isActiveView],
    }.mutableCopy;
    if(self.viewProperty && self.viewProperty.allKeys.count>0){
        [field addEntriesFromDictionary:self.viewProperty];
    }
    if (cpu && cpu.greatestDiff>0) {
        [field setValue:@(cpu.greatestDiff) forKey:FT_CPU_TICK_COUNT];
        if(sTimeSpent>1.0){
            [field setValue:@(cpu.greatestDiff/sTimeSpent) forKey:FT_CPU_TICK_COUNT_PER_SECOND];
        }
    }
    if (memory && memory.maxValue>0) {
        [field setValue:@(memory.meanValue) forKey:FT_MEMORY_AVG];
        [field setValue:@(memory.maxValue) forKey:FT_MEMORY_MAX];
    }
    if (refreshRateInfo && refreshRateInfo.minValue>0) {
        [field setValue:@(refreshRateInfo.minValue) forKey:FT_FPS_MINI];
        [field setValue:@(refreshRateInfo.meanValue) forKey:FT_FPS_AVG];
    }
    if (![self.loading_time isEqual:@0]) {
        [field setValue:self.loading_time forKey:FT_KEY_LOADING_TIME];
    }
    [self.context.writer rumWrite:FT_RUM_SOURCE_VIEW tags:sessionViewTag fields:field time:[FTDateUtil dateTimeNanosecond:self.viewStartTime]];
}

@end
