//
//  FTFatalErrorContext.m
//
//  Created by hulilei on 2024/4/30.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTFatalErrorContext.h"
#import "FTPresetProperty.h"
#import "FTErrorMonitorInfo.h"
#import "FTRUMContext.h"

static BOOL FTDictionaryIsEqual(NSDictionary *a, NSDictionary *b) {
    if (a == b) return YES;
    if (a == nil || b == nil) return NO;
    return [a isEqualToDictionary:b];
}

static BOOL FTObjectIsEqual(id a, id b) {
    if (a == b) return YES;
    if (a == nil || b == nil) return NO;
    return [a isEqual:b];
}

@implementation FTFatalErrorContextModel
- (instancetype)initWithAppState:(nullable NSString *)appState
               lastSessionState:(nullable FTRUMSessionState *)lastSessionState
                 lastViewContext:(nullable NSDictionary *)lastViewContext
                  dynamicContext:(nullable NSDictionary *)dynamicContext
               globalAttributes:(nullable NSDictionary *)globalAttributes
               errorMonitorInfo:(nullable NSDictionary *)errorMonitorInfo {
    if (self = [super init]) {
        _appState = appState;
        _lastSessionState = lastSessionState;
        _lastViewContext = lastViewContext;
        _dynamicContext = dynamicContext;
        _globalAttributes = globalAttributes;
        _errorMonitorInfo = errorMonitorInfo;
    }
    return self;
}

- (instancetype)initWithDict:(NSDictionary *)dict {
    if (!dict) {
        return nil;
    }
    NSString *appState = [dict valueForKey:@"appState"];
    NSDictionary *lastViewContext = [dict valueForKey:@"lastViewContext"];
    FTRUMSessionState *lastSessionState = [[FTRUMSessionState alloc] initWithDict:[dict valueForKey:@"lastSessionState"]];
    NSDictionary *globalAttributes = [dict valueForKey:@"globalAttributes"];
    NSDictionary *errorMonitorInfo = [dict valueForKey:@"errorMonitorInfo"];
    NSDictionary *dynamicContext = [dict valueForKey:@"dynamicContext"];
        
    return [self initWithAppState:appState lastSessionState:lastSessionState lastViewContext:lastViewContext dynamicContext:dynamicContext globalAttributes:globalAttributes errorMonitorInfo:errorMonitorInfo];
}
- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary new];
    [dict setValue:self.lastViewContext forKey:@"lastViewContext"];
    [dict setValue:self.lastSessionState ? [self.lastSessionState toDictionary] : nil forKey:@"lastSessionState"];
    [dict setValue:self.appState forKey:@"appState"];
    [dict setValue:self.globalAttributes forKey:@"globalAttributes"];
    [dict setValue:self.errorMonitorInfo forKey:@"errorMonitorInfo"];
    [dict setValue:self.dynamicContext forKey:@"dynamicContext"];
    return [dict copy];
}

@end

@interface FTFatalErrorContext ()
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, weak) id<FTErrorMonitorInfoProvider> provider;

@property (nonatomic, copy, nullable) NSString *appState;
@property (nonatomic, strong, nullable) FTRUMSessionState *lastSessionState;
@property (nonatomic, strong, nullable) NSDictionary *lastViewContext;
@property (nonatomic, strong, nullable) NSDictionary *dynamicContext;
@property (nonatomic, strong, nullable) NSDictionary *globalAttributes;
@property (nonatomic, strong, nullable) NSDictionary *errorMonitorInfo;
@end
@implementation FTFatalErrorContext
- (instancetype)init{
    return [self initWithErrorInfoProvider:nil];
}
-(instancetype)initWithErrorInfoProvider:(id<FTErrorMonitorInfoProvider>)provider{
    self = [super init];
    if (self) {
        _queue = dispatch_queue_create("com.ft.error-context",DISPATCH_QUEUE_SERIAL);
        _globalAttributes = [[FTPresetProperty sharedInstance] rumTags];
        _provider = provider;
        _errorMonitorInfo = [provider currentErrorMonitorInfo];
        __weak __typeof(self) weakSelf = self;
        [self.provider onErrorMonitorInfoChange:^(NSDictionary * _Nonnull info) {
            weakSelf.errorMonitorInfo = info;
        }];
    }
    return self;
}

- (void)setAppState:(nullable NSString *)appState {
    dispatch_async(self.queue, ^{
        if (FTObjectIsEqual(self.appState, appState)) return;
        self->_appState = appState;
        [self triggerChangeCallbackIfNeeded];
    });
}
-(void)setLastSessionState:(FTRUMSessionState *)lastSessionState{
    dispatch_async(self.queue, ^{
        if (!FTObjectIsEqual(self.lastSessionState,lastSessionState)) {
            self->_lastSessionState = lastSessionState;
            [self triggerChangeCallbackIfNeeded];
        }
    });
}
-(void)setErrorMonitorInfo:(NSDictionary *)errorMonitorInfo{
    dispatch_async(self.queue, ^{
        if (!FTDictionaryIsEqual(self.errorMonitorInfo,errorMonitorInfo)) {
            self->_errorMonitorInfo = errorMonitorInfo;
            [self triggerChangeCallbackIfNeeded];
        }
    });
}
-(void)setDynamicContext:(NSDictionary *)dynamicContext{
    dispatch_async(self.queue, ^{
        if (!FTDictionaryIsEqual(self.dynamicContext,dynamicContext)) {
            self->_dynamicContext = dynamicContext;
            [self triggerChangeCallbackIfNeeded];
        }
    });
}
-(void)setLastViewContext:(NSDictionary *)lastViewContext{
    dispatch_async(self.queue, ^{
        if (!FTDictionaryIsEqual(self.lastViewContext,lastViewContext)) {
            self->_lastViewContext = lastViewContext;
            [self triggerChangeCallbackIfNeeded];
        }
    });
}
- (FTFatalErrorContextModel *)currentContextModel {
    __block FTFatalErrorContextModel *model = nil;
    dispatch_sync(self.queue, ^{
        model = [[FTFatalErrorContextModel alloc] initWithAppState:self.appState
                                                 lastSessionState:self.lastSessionState
                                                   lastViewContext:self.lastViewContext
                                                    dynamicContext:self.dynamicContext
                                                 globalAttributes:self.globalAttributes
                                                 errorMonitorInfo:self.errorMonitorInfo];
    });
    return model;
}
// call in async queue
- (void)triggerChangeCallbackIfNeeded{
    // when lastSessionContext is nil, session not sampled
    if (!self.lastSessionState) return;
    
    if (self.onChange) {
        FTFatalErrorContextModel *model = [[FTFatalErrorContextModel alloc] initWithAppState:self.appState
                                                                            lastSessionState:self.lastSessionState
                                                                             lastViewContext:self.lastViewContext
                                                                              dynamicContext:self.dynamicContext
                                                                            globalAttributes:self.globalAttributes
                                                                            errorMonitorInfo:self.errorMonitorInfo];
        NSDictionary *contextDict = [model toDictionary];
        self.onChange(contextDict);
    }
}

@end
