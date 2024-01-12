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
#import "FTDateUtil.h"
#import "FTConstants.h"
#import "FTInternalLog.h"
static const NSTimeInterval sessionTimeoutDuration = 15 * 60; // 15 minutes
static const NSTimeInterval sessionMaxDuration = 4 * 60 * 60; // 4 hours
@interface FTRUMSessionHandler()<FTRUMSessionProtocol>
@property (nonatomic, strong) FTRUMContext *context;
@property (nonatomic, strong) NSDate *sessionStartTime;
@property (nonatomic, strong) NSDate *lastInteractionTime;
@property (nonatomic, strong) NSMutableArray<FTRUMHandler*> *viewHandlers;
@property (nonatomic, assign) int sampleRate;
@property (nonatomic, assign) BOOL sampling;
@property (nonatomic, assign) BOOL needWriteErrorData;
@property (nonatomic, strong) FTRUMMonitor *monitor;
@end
@implementation FTRUMSessionHandler
-(instancetype)initWithModel:(FTRUMDataModel *)model sampleRate:(int )sampleRate monitor:(FTRUMMonitor *)monitor writer:(id<FTRUMDataWriteProtocol>)writer{
    self = [super init];
    if (self) {
        self.assistant = self;
        self.sampleRate = sampleRate;
        self.sampling = [FTBaseInfoHandler randomSampling:sampleRate];
        self.sessionStartTime = model.time;
        self.viewHandlers = [NSMutableArray new];
        self.context = [FTRUMContext new];
        self.context.writer = writer;
        self.monitor = monitor;
    }
    return  self;
}
-(instancetype)initWithExpiredSession:(FTRUMSessionHandler *)expiredSession time:(NSDate *)time{
    self = [super init];
    if (self) {
        self.assistant = self;
        self.sampleRate = expiredSession.sampleRate;
        self.sampling = [FTBaseInfoHandler randomSampling:expiredSession.sampleRate];
        self.sessionStartTime = time;
        self.context = [FTRUMContext new];
        self.context.writer = expiredSession.context.writer;
        self.monitor = expiredSession.monitor;
        self.viewHandlers = [NSMutableArray new];
        for (FTRUMViewHandler *viewHandler in expiredSession.viewHandlers) {
            if(viewHandler.isActiveView){
                FTRUMViewModel *viewModel = [[FTRUMViewModel alloc]initWithViewID:[FTBaseInfoHandler randomUUID]
                                                                    viewName:viewHandler.view_name viewReferrer:viewHandler.view_referrer];
                viewModel.loading_time = viewHandler.loading_time;
                FTRUMViewHandler *newViewHandler = [[FTRUMViewHandler alloc]initWithModel:viewModel context:self.context monitor:self.monitor];
                [self.viewHandlers addObject:newViewHandler];
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
- (BOOL)process:(FTRUMDataModel *)model {
    if ([self timedOutOrExpired:[NSDate date]]) {
        return NO;
    }
    if (!self.sampling) {
        return YES;
    }
    _lastInteractionTime = [NSDate date];
    self.needWriteErrorData = NO;
    switch (model.type) {
        case FTRUMDataViewStart:
            [self startView:model];
            break;
        case FTRUMDataError:
        case FTRUMDataLongTask:
            self.needWriteErrorData = YES;
            break;
        case FTRUMDataLaunch:
            [self writeLaunchData:(FTRUMLaunchDataModel*)model];
            break;
        case FTRUMDataWebViewJSBData:
            [self writeWebViewJSBData:(FTRUMWebViewData *)model];
            break;
        default:
            break;
    }
    self.viewHandlers = [self.assistant manageChildHandlers:self.viewHandlers byPropagatingData:model];
    // 没有 view 能处理 error\longTask 则由 session 处理写入
    if(self.needWriteErrorData){
        [self writeErrorData:model];
    }
    return  YES;
}
-(void)startView:(FTRUMDataModel *)model{
    
    FTRUMViewHandler *viewHandler = [[FTRUMViewHandler alloc]initWithModel:(FTRUMViewModel *)model context:self.context monitor:self.monitor];
    //当前 view 处理了 error 数据回调,若没有 view 能处理则由 session 处理
    viewHandler.errorHandled = ^{
        self.needWriteErrorData = NO;
    };
    [self.viewHandlers addObject:viewHandler];
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
- (void)writeLaunchData:(FTRUMLaunchDataModel *)model{
    NSDictionary *sessionViewTag = [self getCurrentSessionInfo];
    NSMutableDictionary *tags = [NSMutableDictionary dictionaryWithDictionary:sessionViewTag];
    NSDictionary *actiontags = @{FT_KEY_ACTION_ID:[FTBaseInfoHandler randomUUID],
                                 FT_KEY_ACTION_NAME:model.action_name,
                                 FT_KEY_ACTION_TYPE:model.action_type
    };
    NSDictionary *fields = @{FT_DURATION:model.duration,
                             FT_KEY_ACTION_LONG_TASK_COUNT:@(0),
                             FT_KEY_ACTION_RESOURCE_COUNT:@(0),
                             FT_KEY_ACTION_ERROR_COUNT:@(0),
    };
    [tags addEntriesFromDictionary:actiontags];
    [self.context.writer rumWrite:FT_RUM_SOURCE_ACTION tags:tags fields:fields time:[FTDateUtil dateTimeNanosecond:model.time]];

}
- (void)writeErrorData:(FTRUMDataModel *)model{
    NSDictionary *sessionViewTag = [self getCurrentSessionInfo];
    NSMutableDictionary *tags = [NSMutableDictionary dictionaryWithDictionary:sessionViewTag];
    [tags addEntriesFromDictionary:model.tags];
    NSString *error = model.type == FTRUMDataLongTask?FT_RUM_SOURCE_LONG_TASK :FT_RUM_SOURCE_ERROR;
    [self.context.writer rumWrite:error tags:tags fields:model.fields];
}
- (void)writeWebViewJSBData:(FTRUMWebViewData *)data{
    NSDictionary *sessionTag = @{FT_RUM_KEY_SESSION_ID:self.context.session_id,
                                 FT_RUM_KEY_SESSION_TYPE:self.context.session_type};
    NSMutableDictionary *tags = [NSMutableDictionary new];
    [tags addEntriesFromDictionary:data.tags];
    [tags addEntriesFromDictionary:sessionTag];
    [tags setValue:[FTBaseInfoHandler boolStr:YES] forKey:FT_IS_WEBVIEW];
    NSMutableDictionary *fields = [[NSMutableDictionary alloc]initWithDictionary:data.fields];
    [fields setValue:[FTBaseInfoHandler boolStr:NO] forKey:FT_KEY_IS_ACTIVE];
    [self.context.writer rumWrite:data.measurement tags:tags fields:fields time:data.tm];
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
