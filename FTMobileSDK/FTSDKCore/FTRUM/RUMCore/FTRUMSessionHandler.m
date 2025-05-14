//
//  FTRUMsessionHandler.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/5/26.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTRUMSessionHandler.h"
#import "FTRUMViewHandler.h"
#import "FTBaseInfoHandler.h"
#import "NSDate+FTUtil.h"
#import "FTConstants.h"
#import "FTLog+Private.h"
static const NSTimeInterval sessionTimeoutDuration = 15 * 60; // 15 minutes
static const NSTimeInterval sessionMaxDuration = 4 * 60 * 60; // 4 hours
@interface FTRUMSessionHandler()<FTRUMSessionProtocol>
@property (nonatomic, strong) FTRUMContext *context;
@property (nonatomic, strong) NSDate *sessionStartTime;
@property (nonatomic, strong) NSDate *lastInteractionTime;
@property (nonatomic, strong) NSMutableArray<FTRUMHandler*> *viewHandlers;
@property (nonatomic, assign) BOOL sampling;
@property (nonatomic, assign) BOOL sessionOnErrorSampling;

@property (nonatomic, assign) BOOL needWriteErrorData;
@end
@implementation FTRUMSessionHandler
-(instancetype)initWithModel:(FTRUMDataModel *)model dependencies:(FTRUMDependencies *)dependencies{
    self = [super init];
    if (self) {
        self.rumDependencies = dependencies;
        self.assistant = self;
        self.sessionStartTime = model.time;
        self.viewHandlers = [NSMutableArray new];
        self.context = [[FTRUMContext alloc] initWithAppID:dependencies.appId];
        self.rumDependencies.fatalErrorContext.lastSessionContext = [self.context getGlobalSessionViewTags];
        self.sampling = [FTBaseInfoHandler randomSampling:dependencies.sampleRate];
    }
    return  self;
}
-(instancetype)initWithExpiredSession:(FTRUMSessionHandler *)expiredSession time:(NSDate *)time{
    self = [super init];
    if (self) {
        self.assistant = self;
        self.sampling = [FTBaseInfoHandler randomSampling:expiredSession.rumDependencies.sampleRate];
        self.rumDependencies = expiredSession.rumDependencies;
        self.sessionStartTime = time;
        self.context = [[FTRUMContext alloc]initWithAppID:self.rumDependencies.appId];
        self.viewHandlers = [NSMutableArray new];
        for (FTRUMViewHandler *viewHandler in expiredSession.viewHandlers) {
            if(viewHandler.isActiveView){
                FTRUMViewModel *viewModel = [[FTRUMViewModel alloc]initWithViewID:[FTBaseInfoHandler randomUUID]
                                                                    viewName:viewHandler.view_name viewReferrer:viewHandler.view_referrer];
                viewModel.loading_time = viewHandler.loading_time;
                [self startView:viewModel];
            }
        }
    }
    return  self;
}
-(void)setSampling:(BOOL)sampling{
    _sampling = sampling;
    self.rumDependencies.currentSessionSample = sampling;
    if(!sampling){
        [self.rumDependencies.writer isCacheWriter:NO];
        self.sessionOnErrorSampling = [FTBaseInfoHandler randomSampling:self.rumDependencies.sessionOnErrorSampleRate];
        if(self.sessionOnErrorSampling == YES){
            self.rumDependencies.sampledForErrorSession = YES;
            [self.rumDependencies.writer isCacheWriter:YES];
            FTInnerLogInfo(@"[RUM] The current 'Session' is sampled on error.");
        }else{
            // session 不采集时，防止 logger 关联 rum 错误
            self.rumDependencies.fatalErrorContext = nil;
            FTInnerLogInfo(@"[RUM] The current 'Session' is not sampled.");
        }
    }
}
- (BOOL)process:(FTRUMDataModel *)model context:(nonnull NSDictionary *)context{
    if ([self timedOutOrExpired:[NSDate date]]) {
        return NO;
    }
    if (!self.sampling) {
        if(self.sessionOnErrorSampling == NO){
            return YES;
        }else if(model.type == FTRUMDataError || model.type == FTRUMDataResourceError){
            long long timestamp = [model.time ft_nanosecondTimeStamp];
            self.context.session_error_timestamp = timestamp;
            FTRUMViewHandler *lastViewHandler = (FTRUMViewHandler *)self.viewHandlers.lastObject;
            lastViewHandler.context.session_error_timestamp = timestamp;
        }
    }
    _lastInteractionTime = [NSDate date];
    self.needWriteErrorData = NO;
    switch (model.type) {
        case FTRUMSDKInit:
            [self startInitialView:model];
            break;
        case FTRUMDataViewStart:
            [self startView:model];
            break;
        case FTRUMDataError:
        case FTRUMDataLongTask:
            self.needWriteErrorData = YES;
            break;
        case FTRUMDataLaunch:
            [self writeLaunchData:(FTRUMLaunchDataModel*)model context:context];
            break;
        case FTRUMDataWebViewJSBData:
            [self writeWebViewJSBData:(FTRUMWebViewData *)model context:context];
            break;
        default:
            break;
    }
    self.viewHandlers = [self.assistant manageChildHandlers:self.viewHandlers byPropagatingData:model context:context];
    if(![self hasActivityView]){
        self.rumDependencies.fatalErrorContext.lastSessionContext = [self getCurrentSessionInfo];
    }
    // 没有 view 能处理 error\longTask 则由 session 处理写入
    if(self.needWriteErrorData){
        [self writeErrorData:model context:context];
    }
    return  YES;
}
- (BOOL)hasActivityView{
    for (FTRUMViewHandler *viewHandler in self.viewHandlers) {
        if(viewHandler.isActiveView){
            return YES;
        }
    }
    return NO;
}
-(void)startInitialView:(FTRUMDataModel *)model{
    if(self.viewHandlers.count>0){
        return;
    }
    FTRUMViewModel *viewModel = [[FTRUMViewModel alloc]initWithType:FTRUMSDKInit time:model.time];
    viewModel.isInitialView = YES;
    FTRUMViewHandler *viewHandler = [[FTRUMViewHandler alloc]initWithModel:viewModel context:self.context rumDependencies:self.rumDependencies];
    //当前 view 处理了 error 数据回调,若没有 view 能处理则由 session 处理
    __weak __typeof(self) weakSelf = self;
    viewHandler.errorHandled = ^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.needWriteErrorData = NO;
    };
    [self.viewHandlers addObject:viewHandler];
}
-(void)startView:(FTRUMDataModel *)model{
    
    FTRUMViewHandler *viewHandler = [[FTRUMViewHandler alloc]initWithModel:(FTRUMViewModel *)model context:self.context rumDependencies:self.rumDependencies];
    //当前 view 处理了 error 数据回调,若没有 view 能处理则由 session 处理
    __weak __typeof(self) weakSelf = self;
    viewHandler.errorHandled = ^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.needWriteErrorData = NO;
    };
    [self.viewHandlers addObject:viewHandler];
    self.rumDependencies.fatalErrorContext.lastSessionContext = [self getCurrentSessionInfo];
}
-(BOOL)timedOutOrExpired:(NSDate*)currentTime{
    NSTimeInterval timeElapsedSinceLastInteraction = [currentTime timeIntervalSinceDate:_lastInteractionTime];
    BOOL timedOut = timeElapsedSinceLastInteraction >= sessionTimeoutDuration;

    NSTimeInterval sessionDuration = [currentTime  timeIntervalSinceDate:_sessionStartTime];
    BOOL expired = sessionDuration >= sessionMaxDuration;

    return timedOut || expired;
}
/**
 * launch action
 * 实际意义上 与 click action 不同，action附加resource、error、long task不进行统计
 */
- (void)writeLaunchData:(FTRUMLaunchDataModel *)model context:(NSDictionary *)context{
    
    NSDictionary *sessionViewTag = [model.action_type isEqualToString:FT_LAUNCH_HOT]?[self getCurrentSessionInfo]:[self.context getGlobalSessionTags];
    NSMutableDictionary *tags = [NSMutableDictionary dictionaryWithDictionary:context];
    [tags addEntriesFromDictionary:sessionViewTag];
    [tags setValue:[FTBaseInfoHandler randomUUID] forKey:FT_KEY_ACTION_ID];
    [tags setValue:model.action_name forKey:FT_KEY_ACTION_NAME];
    [tags setValue:model.action_type forKey:FT_KEY_ACTION_TYPE];
    
    NSMutableDictionary *fields = [NSMutableDictionary dictionary];
    [fields setValue:model.duration forKey:FT_DURATION];
    [fields setValue:@(0) forKey:FT_KEY_ACTION_LONG_TASK_COUNT];
    [fields setValue:@(0) forKey:FT_KEY_ACTION_RESOURCE_COUNT];
    [fields setValue:@(0) forKey:FT_KEY_ACTION_ERROR_COUNT];
    [self.rumDependencies.writer rumWrite:FT_RUM_SOURCE_ACTION tags:tags fields:fields time:[model.time ft_nanosecondTimeStamp]];
    
}
- (void)writeErrorData:(FTRUMDataModel *)model context:(NSDictionary *)context{
    FTRUMErrorData *data = (FTRUMErrorData *)model;
    NSDictionary *sessionViewTag = [self getCurrentSessionInfo];
    NSMutableDictionary *tags = [NSMutableDictionary dictionaryWithDictionary:context];
    [tags addEntriesFromDictionary:sessionViewTag];
    [tags addEntriesFromDictionary:model.tags];
    NSMutableDictionary *fields = [NSMutableDictionary new];
    [fields addEntriesFromDictionary:model.fields];
    [fields addEntriesFromDictionary:self.rumDependencies.sampleFieldsDict];
    [fields setValue:@(self.rumDependencies.sessionHasReplay) forKey:FT_SESSION_HAS_REPLAY];
    NSString *error = model.type == FTRUMDataLongTask?FT_RUM_SOURCE_LONG_TASK :FT_RUM_SOURCE_ERROR;
    [self.rumDependencies.writer rumWrite:error tags:tags fields:fields time:data.tm];
}
- (void)writeWebViewJSBData:(FTRUMWebViewData *)data context:(NSDictionary *)context{
    NSDictionary *sessionTag = [self.context getGlobalSessionTags];
    NSMutableDictionary *tags = [NSMutableDictionary new];
    [tags addEntriesFromDictionary:context];
    [tags addEntriesFromDictionary:data.tags];
    [tags addEntriesFromDictionary:sessionTag];
    [tags setValue:@(YES) forKey:FT_IS_WEBVIEW];
    NSMutableDictionary *fields = [[NSMutableDictionary alloc]initWithDictionary:data.fields];
    [fields setValue:@(NO) forKey:FT_KEY_IS_ACTIVE];
    [self.rumDependencies.writer rumWrite:data.measurement tags:tags fields:fields time:data.tm];
}
-(NSString *)getCurrentViewID{
    FTRUMViewHandler *view = (FTRUMViewHandler *)[self.viewHandlers lastObject];
    if (view) {
        return view.context.view_id;
    }
    return nil;
}
-(NSDictionary *)getCurrentErrorSessionInfo{
    FTRUMViewHandler *view = (FTRUMViewHandler *)[self.viewHandlers lastObject];
    if (view) {
        return [view.context getGlobalSessionViewActionTags];
    }
    return [self.context getGlobalSessionViewTags];
}
-(NSDictionary *)getCurrentSessionInfo{
    FTRUMViewHandler *view = (FTRUMViewHandler *)[self.viewHandlers lastObject];
    if (view) {
        return [view.context getGlobalSessionViewTags];
    }
    return [self.context getGlobalSessionViewTags];
}
@end
