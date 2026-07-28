//
//  FTRUMsessionHandler.m
//  FTMobileAgent
//
//  Created by hulilei on 2021/5/26.
//  Copyright 2021 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "FTRUMSessionHandler.h"
#import "FTRUMViewHandler.h"
#import "FTBaseInfoHandler.h"
#import "NSDate+FTUtil.h"
#import "FTConstants.h"
#import "FTInnerLog.h"
#import "FTRUMContext.h"
#import "FTModuleManager.h"
#import "FTInternalConstants.h"
#import "FTRUMManager.h"
static const NSTimeInterval sessionTimeoutDuration = 15 * 60; // 15 minutes
static const NSTimeInterval sessionMaxDuration = 4 * 60 * 60; // 4 hours
static NSString * const FTRUMFallbackViewNameApplicationLaunch = @"ApplicationLaunch";
static NSString * const FTRUMFallbackViewNameBackground = @"BackgroundView";
static NSString * const FTRUMFallbackViewNameRoot = @"RootView";
static NSString * const FTRUMFallbackViewReferrerRoot = @"root";
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
        self.context = [[FTRUMContext alloc] initWithSampleRate:dependencies.sampleRate sessionOnErrorSampleRate:dependencies.sessionOnErrorSampleRate appId:dependencies.appId];
        self.appState = FTAppStateStartUp;
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
        self.context = [[FTRUMContext alloc]initWithSampleRate:expiredSession.rumDependencies.sampleRate sessionOnErrorSampleRate:expiredSession.rumDependencies.sessionOnErrorSampleRate appId:self.rumDependencies.appId];
        self.appState = expiredSession.appState;
        self.viewHandlers = [NSMutableArray new];
        for (FTRUMViewHandler *viewHandler in expiredSession.viewHandlers) {
            if (!viewHandler.isActiveView) {
                continue;
            }
            // Synthetic views are scoped to their original session and must not affect the next one.
            if (viewHandler.fallbackView) {
                FTRUMViewModel *viewStopModel = [[FTRUMViewModel alloc]initWithViewID:viewHandler.view_id
                                                                              viewName:viewHandler.view_name
                                                                          viewReferrer:viewHandler.view_referrer];
                viewStopModel.time = time;
                viewStopModel.type = FTRUMDataViewStop;
                [viewHandler.assistant process:viewStopModel context:@{}];
                continue;
            }
            FTRUMViewModel *viewModel = [[FTRUMViewModel alloc]initWithViewID:[FTBaseInfoHandler randomUUID]
                                                                     viewName:viewHandler.view_name viewReferrer:viewHandler.view_referrer];
            viewModel.time = time;
            viewModel.loading_time = viewHandler.loading_time;
            [self startView:viewModel];
        }
    }
    return  self;
}
-(void)setSampling:(BOOL)sampling{
    _sampling = sampling;
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
    _lastInteractionTime = [NSDate date];
    if (!self.sampling) {
        if(self.sessionOnErrorSampling == NO){
            return YES;
        }else if(model.type == FTRUMDataError || model.type == FTRUMDataResourceError){
            long long timestamp = model.tm;
            self.context.sessionState.session_error_timestamp = timestamp;
            FTRUMViewHandler *lastViewHandler = (FTRUMViewHandler *)self.viewHandlers.lastObject;
            lastViewHandler.context.sessionState.session_error_timestamp = timestamp;
            [self.rumDependencies.fatalErrorContext setLastSessionState:[self.context.sessionState copy]];
        }
    }
    self.rumDependencies.fatalErrorContext.dynamicContext = context;
    switch (model.type) {
        case FTRUMDataViewStart:
            [self startView:model];
            break;
        case FTRUMDataViewUpdateLoadingTime:
            if(![self hasActivityView]){
                return YES;
            }
            break;
        case FTRUMDataWebViewJSBData:
            [self writeWebViewJSBData:(FTRUMWebViewData *)model context:context];
            break;
        case FTRUMDataStartAction:
        case FTRUMDataAddAction:
        case FTRUMDataError:
        case FTRUMDataLongTask:
        case FTRUMDataResourceStart:
            [self prepareFallbackViewForModel:model context:context];
            break;
        case FTRUMDataLaunch:
            if (((FTRUMLaunchDataModel *)model).isInitialLaunchAction) {
                [self prepareApplicationLaunchFallbackForModel:model];
            } else {
                [self prepareFallbackViewForModel:model context:context];
            }
            break;
        default:
            break;
    }
    self.viewHandlers = [self.assistant manageChildHandlers:self.viewHandlers byPropagatingData:model context:context];
    
    if(![self hasActivityView]){
        [self.rumDependencies.fatalErrorContext setLastViewContext:nil];
        self.rumDependencies.lastViewUserCustomDatas = nil;
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
    return [self activeViewHandler] != nil;
}
-(FTRUMViewHandler *)activeViewHandler{
    for (FTRUMViewHandler *viewHandler in [self.viewHandlers reverseObjectEnumerator]) {
        if(viewHandler.isActiveView){
            return viewHandler;
        }
    }
    return nil;
}
-(FTRUMViewHandler *)activeFallbackViewHandlerWithName:(NSString *)viewName{
    for (FTRUMViewHandler *viewHandler in [self.viewHandlers reverseObjectEnumerator]) {
        if(viewHandler.isActiveView && viewHandler.fallbackView && [viewHandler.view_name isEqualToString:viewName]){
            return viewHandler;
        }
    }
    return nil;
}
-(void)prepareFallbackViewForModel:(FTRUMDataModel *)model context:(NSDictionary *)context{
    NSString *fallbackViewName = [self fallbackViewNameForModel:model];
    FTRUMViewHandler *activeViewHandler = [self activeViewHandler];
    if(!activeViewHandler){
        [self startFallbackViewWithName:fallbackViewName time:model.time];
    }else if(activeViewHandler.fallbackView && ![activeViewHandler.view_name isEqualToString:fallbackViewName]){
        [self startFallbackViewByClosingActiveFallbackWithName:fallbackViewName time:model.time context:context];
    }
}
-(void)prepareApplicationLaunchFallbackForModel:(FTRUMDataModel *)model{
    FTRUMViewHandler *applicationLaunchViewHandler = [self activeFallbackViewHandlerWithName:FTRUMFallbackViewNameApplicationLaunch];
    if (applicationLaunchViewHandler) {
        [applicationLaunchViewHandler updateViewStartTimeIfEarlierThan:model.time];
        return;
    }
    FTRUMViewHandler *activeViewHandler = [self activeViewHandler];
    applicationLaunchViewHandler = [self startFallbackViewWithName:FTRUMFallbackViewNameApplicationLaunch time:model.time];
    applicationLaunchViewHandler.closeAfterInitialLaunchAction = activeViewHandler != nil;
}
-(NSString *)fallbackViewNameForModel:(FTRUMDataModel *)model{
    NSString *errorSituation = model.tags[FT_KEY_ERROR_SITUATION];
    if ([errorSituation isEqualToString:FTStringFromAppState(FTAppStateStartUp)]) {
        return FTRUMFallbackViewNameApplicationLaunch;
    }
    if ([errorSituation isEqualToString:FTStringFromAppState(FTAppStateBackground)]) {
        return FTRUMFallbackViewNameBackground;
    }
    switch (self.appState) {
        case FTAppStateStartUp:
            return FTRUMFallbackViewNameApplicationLaunch;
        case FTAppStateBackground:
            return FTRUMFallbackViewNameBackground;
        default:
            return FTRUMFallbackViewNameRoot;
    }
}
-(FTRUMViewModel *)fallbackViewModelWithName:(NSString *)viewName time:(NSDate *)time{
    FTRUMViewModel *viewModel = [[FTRUMViewModel alloc]initWithViewID:[FTBaseInfoHandler randomUUID]
                                                             viewName:viewName
                                                         viewReferrer:FTRUMFallbackViewReferrerRoot];
    viewModel.time = time;
    viewModel.loading_time = @(-1);
    viewModel.type = FTRUMDataViewStart;
    return viewModel;
}
-(FTRUMViewHandler *)startFallbackViewWithName:(NSString *)viewName time:(NSDate *)time{
    return [self startFallbackViewWithModel:[self fallbackViewModelWithName:viewName time:time]];
}
-(FTRUMViewHandler *)startFallbackViewByClosingActiveFallbackWithName:(NSString *)viewName time:(NSDate *)time context:(NSDictionary *)context{
    FTRUMViewModel *viewModel = [self fallbackViewModelWithName:viewName time:time];
    self.viewHandlers = [self.assistant manageChildHandlers:self.viewHandlers byPropagatingData:viewModel context:context];
    return [self startFallbackViewWithModel:viewModel];
}
-(FTRUMViewHandler *)startFallbackViewWithModel:(FTRUMViewModel *)viewModel{
    FTRUMViewHandler *viewHandler = [[FTRUMViewHandler alloc]initWithModel:viewModel context:self.context rumDependencies:self.rumDependencies needsMonitoring:NO];
    viewHandler.fallbackView = YES;
    viewHandler.isApplicationLaunchView = [viewModel.view_name isEqualToString:FTRUMFallbackViewNameApplicationLaunch];
    [self.viewHandlers addObject:viewHandler];
    return viewHandler;
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
