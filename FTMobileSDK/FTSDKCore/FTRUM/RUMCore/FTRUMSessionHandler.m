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
@property (nonatomic, assign) BOOL needWriteErrorData;
@end
@implementation FTRUMSessionHandler
-(instancetype)initWithModel:(FTRUMDataModel *)model dependencies:(FTRUMDependencies *)dependencies{
    self = [super init];
    if (self) {
        self.rumDependencies = dependencies;
        self.assistant = self;
        self.sampling = [FTBaseInfoHandler randomSampling:dependencies.sampleRate];
        self.sessionStartTime = model.time;
        self.viewHandlers = [NSMutableArray new];
        self.context = [FTRUMContext new];
        self.rumDependencies.fatalErrorContext.lastSessionContext = [self.context getGlobalSessionViewTags];
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
        self.context = [FTRUMContext new];
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
    if(!sampling){
        FTInnerLogInfo(@"[RUM] The current 'Session' is not sampled.");
    }
}
- (BOOL)process:(FTRUMDataModel *)model context:(nonnull NSDictionary *)context{
    if ([self timedOutOrExpired:[NSDate date]]) {
        return NO;
    }
    if (!self.sampling) {
        if((model.type == FTRUMDataError || model.type == FTRUMDataResourceError) && self.rumDependencies.sessionOnErrorSampleRate){
            self.sampling = YES;
            self.context.is_error_session = YES;
            [self writeErrorData:model context:context];
            [self startInitialView:model];
        }
        return YES;
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
        weakSelf.needWriteErrorData = NO;
    };
    [self.viewHandlers addObject:viewHandler];
}
-(void)startView:(FTRUMDataModel *)model{
    
    FTRUMViewHandler *viewHandler = [[FTRUMViewHandler alloc]initWithModel:(FTRUMViewModel *)model context:self.context rumDependencies:self.rumDependencies];
    //当前 view 处理了 error 数据回调,若没有 view 能处理则由 session 处理
    __weak __typeof(self) weakSelf = self;
    viewHandler.errorHandled = ^{
        weakSelf.needWriteErrorData = NO;
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
    
    NSDictionary *sessionViewTag = [model.action_type isEqualToString:FT_LAUNCH_HOT]?[self getCurrentSessionInfo]:@{FT_RUM_KEY_SESSION_ID:self.context.session_id,FT_RUM_KEY_SESSION_TYPE:self.context.session_type};
    NSMutableDictionary *tags = [NSMutableDictionary dictionaryWithDictionary:context];
    [tags addEntriesFromDictionary:sessionViewTag];
    NSDictionary *actionTags = @{FT_KEY_ACTION_ID:[FTBaseInfoHandler randomUUID],
                                 FT_KEY_ACTION_NAME:model.action_name,
                                 FT_KEY_ACTION_TYPE:model.action_type
    };
    NSDictionary *fields = @{FT_DURATION:model.duration,
                             FT_KEY_ACTION_LONG_TASK_COUNT:@(0),
                             FT_KEY_ACTION_RESOURCE_COUNT:@(0),
                             FT_KEY_ACTION_ERROR_COUNT:@(0),
    };
    [tags addEntriesFromDictionary:actionTags];
    [self.rumDependencies.writer rumWrite:FT_RUM_SOURCE_ACTION tags:tags fields:fields time:[model.time ft_nanosecondTimeStamp]];

}
- (void)writeErrorData:(FTRUMDataModel *)model context:(NSDictionary *)context{
    FTRUMErrorData *data = (FTRUMErrorData *)model;
    NSDictionary *sessionViewTag = [self getCurrentSessionInfo];
    NSMutableDictionary *tags = [NSMutableDictionary dictionaryWithDictionary:context];
    [tags addEntriesFromDictionary:sessionViewTag];
    [tags addEntriesFromDictionary:model.tags];
    NSString *error = model.type == FTRUMDataLongTask?FT_RUM_SOURCE_LONG_TASK :FT_RUM_SOURCE_ERROR;
    [self.rumDependencies.writer rumWrite:error tags:tags fields:model.fields time:data.tm];
}
- (void)writeWebViewJSBData:(FTRUMWebViewData *)data context:(NSDictionary *)context{
    NSDictionary *sessionTag = @{FT_RUM_KEY_SESSION_ID:self.context.session_id,
                                 FT_RUM_KEY_SESSION_TYPE:self.context.session_type};
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
