//
//  FTRUMViewHandler.m
//  FTMobileAgent
//
//  Created by hulilei on 2021/5/24.
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
@property (nonatomic, strong) NSMutableDictionary *resourceHandlers;
@property (nonatomic, assign) NSInteger viewLongTaskCount;
@property (nonatomic, assign) NSInteger viewResourceCount;
@property (nonatomic, assign) NSInteger viewErrorCount;
@property (nonatomic, assign) NSInteger viewActionCount;
@property (nonatomic, assign) BOOL didReceiveStartData;
@property (nonatomic, strong) NSDate *viewStartTime;
@property (nonatomic, assign) BOOL needUpdateView;
@property (nonatomic, strong) FTMonitorItem *monitorItem;
@property (nonatomic, strong) NSMutableDictionary *viewProperty;//Stored in field
@property (nonatomic, assign) uint64_t updateTime;
@property (nonatomic, assign) BOOL sessionHasReplay;
@end
@implementation FTRUMViewHandler
-(instancetype)initWithModel:(FTRUMViewModel *)model context:(nonnull FTRUMContext *)context rumDependencies:(FTRUMDependencies *)rumDependencies{
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
        self.rumDependencies = rumDependencies;
        self.sessionHasReplay = [rumDependencies.sessionHasReplay boolValue];
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
        case FTRUMDataViewUpdateLoadingTime:
            if (self.isActiveView) {
                FTRUMViewLoadingModel *loadingModel = (FTRUMViewLoadingModel *)model;
                self.loading_time = loadingModel.duration;
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
        [self writeViewData:model context:context updateTime:model.time];
    }
    return !shouldComplete;
}
-(void)setViewErrorCount:(NSInteger)viewErrorCount{
    _viewErrorCount = viewErrorCount;
    if (self.rumDependencies.sampledForErrorReplay) {
        self.sessionHasReplay = YES;
    }
}
- (void)startAction:(FTRUMDataModel *)model{
    __weak typeof(self) weakSelf = self;
    FTRUMActionHandler *actionHandler = [[FTRUMActionHandler alloc]initWithModel:(FTRUMActionModel *)model context:self.context dependencies:self.rumDependencies];
    actionHandler.handler = ^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.viewActionCount +=1;
        strongSelf.needUpdateView = YES;
        strongSelf.context.action_id = nil;
        strongSelf.context.action_name = nil;
    };
    self.actionHandler = actionHandler;
}
- (void)addAction:(FTRUMDataModel *)model context:(NSDictionary *)context{
    __weak typeof(self) weakSelf = self;
    FTRUMActionHandler *actionHandler = [[FTRUMActionHandler alloc]initWithModel:(FTRUMActionModel *)model context:self.context dependencies:self.rumDependencies];
    model.type = FTRUMDataStopAction;
    actionHandler.handler = ^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.viewActionCount +=1;
        strongSelf.needUpdateView = YES;
    };
    [actionHandler.assistant process:model context:context];
}
- (void)startResource:(FTRUMResourceDataModel *)model{
    __weak typeof(self) weakSelf = self;
    FTRUMResourceHandler *resourceHandler = [[FTRUMResourceHandler alloc] initWithModel:model context:self.context dependencies:self.rumDependencies];
    resourceHandler.resourceHandler = ^(BOOL add){
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        if(add){
            strongSelf.viewResourceCount+=1;
            strongSelf.needUpdateView = YES;
        }
    };
    resourceHandler.errorHandler = ^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.viewErrorCount+=1;
    };
    self.resourceHandlers[model.identifier] =resourceHandler;
}
- (void)writeErrorData:(FTRUMDataModel *)model context:(NSDictionary *)context{
    NSDictionary *sessionViewTag = [self.context getGlobalSessionViewActionTags];
    NSMutableDictionary *tags = [NSMutableDictionary dictionaryWithDictionary:context];
    [tags addEntriesFromDictionary:sessionViewTag];
    [tags addEntriesFromDictionary:model.tags];
    NSMutableDictionary *fields = [NSMutableDictionary new];
    [fields addEntriesFromDictionary:model.fields];
    if (self.rumDependencies.sessionHasReplay != nil) {
        BOOL sessionHasReplay = self.sessionHasReplay || self.rumDependencies.sessionHasReplay.boolValue;
        [fields setValue:@(sessionHasReplay) forKey:FT_SESSION_HAS_REPLAY];
    }
    NSString *error = model.type == FTRUMDataLongTask?FT_RUM_SOURCE_LONG_TASK :FT_RUM_SOURCE_ERROR;
    [self.rumDependencies.writer rumWrite:error tags:tags fields:fields time:model.tm];
}
- (void)writeViewData:(FTRUMDataModel *)model context:(NSDictionary *)context updateTime:(NSDate *)updateTime{
    self.updateTime+=1;
    //Second level
    NSTimeInterval sTimeSpent = MAX(1e-9, [model.time timeIntervalSinceDate:self.viewStartTime]);
    //Nanosecond level
    NSNumber *nTimeSpent = [NSNumber numberWithLongLong:sTimeSpent * 1000000000];
    
    NSMutableDictionary *tags = [NSMutableDictionary dictionaryWithDictionary:context];
    [tags addEntriesFromDictionary:[self.context getGlobalSessionViewTags]];
    FTMonitorValue *cpu = self.monitorItem.cpu;
    FTMonitorValue *memory = self.monitorItem.memory;
    FTMonitorValue *refreshRateInfo = self.monitorItem.refreshDisplay;
    NSMutableDictionary *fields = [NSMutableDictionary dictionary];
    [fields setValue:@(self.viewErrorCount) forKey:FT_KEY_VIEW_ERROR_COUNT];
    [fields setValue:@(self.viewResourceCount) forKey:FT_KEY_VIEW_RESOURCE_COUNT];
    [fields setValue:@(self.viewLongTaskCount) forKey:FT_KEY_VIEW_LONG_TASK_COUNT];
    [fields setValue:@(self.viewActionCount) forKey:FT_KEY_VIEW_ACTION_COUNT];
    [fields setValue:nTimeSpent forKey:FT_KEY_TIME_SPENT];
    [fields setValue:@(self.updateTime) forKey:FT_KEY_VIEW_UPDATE_TIME];
    [fields setValue:@(self.isActiveView) forKey:FT_KEY_IS_ACTIVE];
    
    [fields setValue:@(self.rumDependencies.sampledForErrorSession) forKey:FT_RUM_KEY_SAMPLED_FOR_ERROR_SESSION];
    [fields addEntriesFromDictionary:self.rumDependencies.sessionReplaySampledFields];
    // session-replay
    if (self.rumDependencies.sessionHasReplay != nil) {
        BOOL sessionHasReplay = self.sessionHasReplay || self.rumDependencies.sessionHasReplay;
        [fields setValue:@(sessionHasReplay) forKey:FT_SESSION_HAS_REPLAY];
        if (sessionHasReplay) {
            NSDictionary *dict = [self.rumDependencies.sessionReplayStats valueForKey:self.view_id];
            if(dict){
                [fields setValue:dict forKey:FT_SESSION_REPLAY_STATS];
            }
        }
    }
    if(self.viewProperty && self.viewProperty.allKeys.count>0){
        [fields addEntriesFromDictionary:self.viewProperty];
    }
    if (cpu && cpu.greatestDiff>=0) {
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
    if (self.context.session_error_timestamp > 0) {
        [fields setValue:@(self.context.session_error_timestamp) forKey:FT_SESSION_ERROR_TIMESTAMP];
    }
    long long time = [self.viewStartTime ft_nanosecondTimeStamp];
    [self.rumDependencies.writer rumWrite:FT_RUM_SOURCE_VIEW tags:tags fields:fields time:time updateTime:[updateTime ft_nanosecondTimeStamp]];
    self.rumDependencies.fatalErrorContext.lastViewContext = @{@"tags":tags,
                                                               @"fields":fields,
                                                               @"time":[NSNumber numberWithLongLong:time]
    };
}

@end
