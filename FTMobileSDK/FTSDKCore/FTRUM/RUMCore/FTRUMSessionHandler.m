//
//  FTRUMsessionHandler.m
//  FTMobileAgent
//
//  Created by hulilei on 2021/5/26.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTRUMSessionHandler.h"
#import "FTRUMViewHandler.h"
#import "FTBaseInfoHandler.h"
#import "NSDate+FTUtil.h"
#import "FTConstants.h"
#import "FTLog+Private.h"
#import "FTRUMPlaceholderViewHandler.h"
#import "FTRUMContext.h"

static const NSTimeInterval sessionTimeoutDuration = 15 * 60; // 15 minutes
static const NSTimeInterval sessionMaxDuration = 4 * 60 * 60; // 4 hours
@interface FTRUMSessionHandler()<FTRUMSessionProtocol>
@property (nonatomic, strong) FTRUMContext *context;
@property (nonatomic, strong) NSDate *sessionStartTime;
@property (nonatomic, strong) NSDate *lastInteractionTime;
@property (nonatomic, strong) NSMutableArray<FTRUMHandler*> *viewHandlers;
@property (nonatomic, assign) BOOL sampling;
@property (nonatomic, assign) BOOL sessionOnErrorSampling;

@end
@implementation FTRUMSessionHandler
-(instancetype)initWithModel:(FTRUMDataModel *)model dependencies:(FTRUMDependencies *)dependencies{
    self = [super init];
    if (self) {
        self.rumDependencies = dependencies;
        self.assistant = self;
        self.sessionStartTime = model.time;
        self.viewHandlers = [NSMutableArray new];
        self.context = [[FTRUMContext alloc] initWithSampleRate:dependencies.sampleRate sessionOnErrorSampleRate:dependencies.sessionOnErrorSampleRate];
        self.sampling = [FTBaseInfoHandler randomSampling:dependencies.sampleRate];
    }
    return  self;
}
-(instancetype)initWithExpiredSession:(FTRUMSessionHandler *)expiredSession time:(NSDate *)time{
    self = [super init];
    if (self) {
        self.assistant = self;
        self.rumDependencies = expiredSession.rumDependencies;
        self.sampling = [FTBaseInfoHandler randomSampling:expiredSession.rumDependencies.sampleRate];
        self.sessionStartTime = time;
        self.context = [[FTRUMContext alloc]initWithSampleRate:expiredSession.rumDependencies.sampleRate sessionOnErrorSampleRate:expiredSession.rumDependencies.sessionOnErrorSampleRate];
        self.viewHandlers = [NSMutableArray new];
        for (FTRUMViewHandler *viewHandler in expiredSession.viewHandlers) {
            if(viewHandler.isActiveView && [viewHandler isKindOfClass:FTRUMViewHandler.class]){
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
    [self updateWriterCacheWriterState:NO];
    FTRUMSessionState *sessionState = self.context.sessionState;
    if (!sampling) {
        CGFloat errorSampleRate = self.rumDependencies.sessionOnErrorSampleRate;
        BOOL sessionOnErrorSamplingResult = [FTBaseInfoHandler randomSampling:errorSampleRate];
        self.sessionOnErrorSampling = sessionOnErrorSamplingResult;
        
        if (sessionOnErrorSamplingResult) {
            self.context.sessionState.sampled_for_error_session = YES;
            [self updateWriterCacheWriterState:YES];
            FTInnerLogInfo(@"[RUM] The current 'Session' is sampled on error.");
        } else {
            sessionState = nil;
            FTInnerLogInfo(@"[RUM] The current 'Session' is not sampled.");
        }
    }
    self.rumDependencies.fatalErrorContext.lastSessionState = sessionState;
}
- (void)updateWriterCacheWriterState:(BOOL)enable {
    id writer = self.rumDependencies.writer;
    if ([writer respondsToSelector:@selector(isCacheWriter:)]) {
        [writer isCacheWriter:enable];
    }
}
- (BOOL)process:(FTRUMDataModel *)model context:(nonnull NSDictionary *)context{
    if ([self timedOutOrExpired:[NSDate date]]) {
        return NO;
    }
    if (model.type == FTRUMSampleRateUpdate) {
        return  [self checkSessionStateForSamplingRateUpdate];
    }
    if (!self.sampling) {
        if(self.sessionOnErrorSampling == NO){
            return YES;
        }else{
            if(model.type == FTRUMDataError || model.type == FTRUMDataResourceError){
                long long timestamp = model.tm;
                self.context.sessionState.session_error_timestamp = timestamp;
                FTRUMViewHandler *lastViewHandler = (FTRUMViewHandler *)self.viewHandlers.lastObject;
                lastViewHandler.context.sessionState.session_error_timestamp = timestamp;
                [self.rumDependencies.fatalErrorContext setLastSessionState:[self.context.sessionState copy]];
            }
        }
    }
    self.rumDependencies.fatalErrorContext.dynamicContext = context;
    _lastInteractionTime = [NSDate date];
    BOOL isResourceUpdate = NO;
    switch (model.type) {
        case FTRUMDataViewStart:
            [self startView:model];
            break;
        case FTRUMDataViewUpdateLoadingTime:
            if(![self hasActivityView]){
                return YES;
            }
            break;
        case FTRUMDataLaunch:
            [self writeLaunchData:(FTRUMLaunchDataModel*)model context:context];
            break;
        case FTRUMDataWebViewJSBData:
            [self writeWebViewJSBData:(FTRUMWebViewData *)model context:context];
            break;
        case FTRUMDataResourceComplete:
        case FTRUMDataResourceAbandon:
        case FTRUMDataResourceStop:
        case FTRUMDataResourceError:
            isResourceUpdate = YES;
            break;
        default:
            break;
    }
    if(![self hasActivityView] && !isResourceUpdate){
        [self startPlaceholderView:model];
    }
    self.viewHandlers = [self.assistant manageChildHandlers:self.viewHandlers byPropagatingData:model context:context];
    
    if(![self hasActivityView]){
        [self.rumDependencies.fatalErrorContext setLastViewContext:nil];
    }
    return  YES;
}
- (BOOL)checkSessionStateForSamplingRateUpdate{
    // 1. The previous session is being sampled; end the current session if the updated sampling rate is set to non-sampling
    if (self.sampling) {
        if (self.rumDependencies.sampleRate == 0) {
            return NO;
        }
    } else {
        // The previous session was not sampled
        // 2.1. End the current session if the updated sampling rate is set to full sampling
        if (self.rumDependencies.sampleRate == 100) {
            return NO;
        }
        // 2.2. The previous session was performing error sampling; end the current session if the updated error sampling is disabled
        if (self.sessionOnErrorSampling && self.rumDependencies.sessionOnErrorSampleRate == 0) {
            return NO;
        }
        // 2.3. The previous session was not performing error sampling; end the current session if the updated error sampling is set to full sampling
        if (!self.sessionOnErrorSampling && self.rumDependencies.sessionOnErrorSampleRate == 100) {
            return NO;
        }
    }
    return YES;
}
- (BOOL)hasActivityView{
    if (self.viewHandlers.count == 0) {
        return NO;
    }
    for (FTRUMViewHandler *viewHandler in self.viewHandlers) {
        if(viewHandler.isActiveView){
            return YES;
        }
    }
    return NO;
}
-(void)startPlaceholderView:(FTRUMDataModel *)model{
    FTRUMViewModel *viewModel = [[FTRUMViewModel alloc]initWithType:FTRUMViewPlaceholder time:model.time];
    FTRUMPlaceholderViewHandler *viewHandler = [[FTRUMPlaceholderViewHandler alloc]initWithModel:viewModel context:self.context rumDependencies:self.rumDependencies needsMonitoring:YES];
    [self.viewHandlers addObject:viewHandler];
}
-(void)startView:(FTRUMDataModel *)model{
    FTRUMViewHandler *viewHandler = [[FTRUMViewHandler alloc]initWithModel:(FTRUMViewModel *)model context:self.context rumDependencies:self.rumDependencies];
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
 * In actual meaning, different from click action, action attached resource, error, long task are not counted
 */
- (void)writeLaunchData:(FTRUMLaunchDataModel *)model context:(NSDictionary *)context{
    
    NSDictionary *sessionViewTag = [model.action_type isEqualToString:FT_LAUNCH_HOT]?[self getCurrentSessionInfo]:[self.context getGlobalSessionTags];
    NSMutableDictionary *tags = [NSMutableDictionary new];
    [tags addEntriesFromDictionary:sessionViewTag];
    [tags setValue:[FTBaseInfoHandler randomUUID] forKey:FT_KEY_ACTION_ID];
    [tags setValue:model.action_name forKey:FT_KEY_ACTION_NAME];
    [tags setValue:model.action_type forKey:FT_KEY_ACTION_TYPE];
    
    NSMutableDictionary *fields = [NSMutableDictionary dictionary];
    if (model.fields) {
        [fields addEntriesFromDictionary:model.fields];
    }
    [fields setValue:model.duration forKey:FT_DURATION];
    [fields setValue:@(0) forKey:FT_KEY_ACTION_LONG_TASK_COUNT];
    [fields setValue:@(0) forKey:FT_KEY_ACTION_RESOURCE_COUNT];
    [fields setValue:@(0) forKey:FT_KEY_ACTION_ERROR_COUNT];
    [fields addEntriesFromDictionary:self.context.sessionState.sessionFields];
    [self.rumDependencies.writer rumWrite:FT_RUM_SOURCE_ACTION tags:tags fields:fields dynamicContext:context time:model.tm];
    
}
- (void)writeWebViewJSBData:(FTRUMWebViewData *)data context:(NSDictionary *)context{
    NSDictionary *sessionTag = [self.context getGlobalSessionTags];
    NSMutableDictionary *tags = [NSMutableDictionary new];
    [tags addEntriesFromDictionary:data.tags];
    [tags addEntriesFromDictionary:sessionTag];
    [tags setValue:@(YES) forKey:FT_IS_WEBVIEW];
    NSMutableDictionary *fields = [[NSMutableDictionary alloc]initWithDictionary:data.fields];
    [fields setValue:@(NO) forKey:FT_KEY_IS_ACTIVE];
    [fields addEntriesFromDictionary:self.context.sessionState.sessionFields];
    [self.rumDependencies.writer rumWrite:data.measurement tags:tags fields:fields dynamicContext:context time:data.tm];
}
-(NSString *)getCurrentViewID{
    FTRUMViewHandler *view = (FTRUMViewHandler *)[self.viewHandlers lastObject];
    if (view) {
        return view.context.view_id;
    }
    return nil;
}
-(NSDictionary *)getCurrentSessionInfo{
    FTRUMViewHandler *view = (FTRUMViewHandler *)[self.viewHandlers lastObject];
    if (view) {
        return [view.context getGlobalSessionViewActionTags];
    }
    return [self.context getGlobalSessionViewTags];
}
@end
