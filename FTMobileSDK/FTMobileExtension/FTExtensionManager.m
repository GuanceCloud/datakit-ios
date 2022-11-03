//
//  FTExtensionManager.m
//  FTMobileExtension
//
//  Created by 胡蕾蕾 on 2020/11/13.
//  Copyright © 2020 hll. All rights reserved.
//

#import "FTExtensionManager.h"
#import "FTExtensionDataManager.h"
#import "FTUncaughtExceptionHandler.h"
#import "FTDateUtil.h"
#import "FTLog.h"
#import "FTRUMManager.h"
#import "FTRUMDataWriteProtocol.h"
#import "FTMobileConfig.h"
#import "FTURLSessionAutoInstrumentation.h"
#import "FTTracer.h"
#import "FTExternalDataManager+Private.h"
#import "FTBaseInfoHandler.h"
#import "NSString+FTAdd.h"
#import "FTConstants.h"
#import "FTMobileConfig+Private.h"
@interface FTExtensionManager ()<FTRUMDataWriteProtocol>
@property (nonatomic, strong) FTRUMManager *rumManager;
@property (nonatomic, strong) FTURLSessionAutoInstrumentation *sessionInstrumentation;
@property (nonatomic, strong) FTLoggerConfig *loggerConfig;
@property (nonatomic, strong) FTExtensionConfig *extensionConfig;
@property (nonatomic, strong) NSSet *logLevelFilterSet;
@end
@implementation FTExtensionManager
static FTExtensionManager *sharedInstance = nil;
+ (instancetype)sharedInstance{
    NSAssert(sharedInstance, @"请先使用 startWithApplicationGroupIdentifier: 初始化");
    return sharedInstance;
}
+ (void)startWithExtensionConfig:(FTExtensionConfig *)extensionConfig{
    NSAssert((extensionConfig.groupIdentifier.length!=0 ), @"请填写Group Identifier");
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[FTExtensionManager alloc]initWithExtensionConfig:extensionConfig];
    });
}
-(instancetype)initWithExtensionConfig:(FTExtensionConfig *)extensionConfig{
    self = [super init];
    if (self) {
        _extensionConfig = extensionConfig;
        [FTLog enableLog:extensionConfig.enableSDKDebugLog];
        [self processingConfigItems];
    }
    return self;
}
- (void)processingConfigItems{
    NSDictionary *rumDict = [[FTExtensionDataManager sharedInstance] getRumConfigWithGroupIdentifier:self.extensionConfig.groupIdentifier];
    NSDictionary *traceDict = [[FTExtensionDataManager sharedInstance] getTraceConfigWithGroupIdentifier:self.extensionConfig.groupIdentifier];
    NSDictionary *loggerDict = [[FTExtensionDataManager sharedInstance] getLoggerConfigWithGroupIdentifier:self.extensionConfig.groupIdentifier];
   
    FTRumConfig *rumConfig =[[FTRumConfig alloc]initWithDictionary:rumDict];
    FTTraceConfig *traceConfig =[[FTTraceConfig alloc]initWithDictionary:traceDict];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]initWithDictionary:loggerDict];
    if(rumConfig){
        rumConfig.enableTraceUserResource = self.extensionConfig.enableAutoTraceResource;
        rumConfig.enableTrackAppCrash = self.extensionConfig.enableTrackAppCrash;
        [self startRumWithConfigOptions:rumConfig];
    }
    if(traceConfig){
        [self startTraceWithConfigOptions:traceConfig];
    }
    self.loggerConfig = loggerConfig;
}
- (void)startRumWithConfigOptions:(FTRumConfig *)rumConfigOptions{
    [self.sessionInstrumentation setRUMConfig:rumConfigOptions];
    self.rumManager = [[FTRUMManager alloc] initWithRumConfig:rumConfigOptions monitor:nil wirter:self];
    self.rumManager.appState = AppStateUnknown;
    id <FTAddRumDatasProtocol> rum = self.rumManager;
    [[FTExternalDataManager sharedManager] setDelegate:rum];
    
    if (rumConfigOptions.enableTrackAppCrash){
        [[FTUncaughtExceptionHandler sharedHandler] addftSDKInstance:self.rumManager];
    }
    [FTURLSessionAutoInstrumentation sharedInstance].interceptor.innerResourceHandeler = self.rumManager;
}
- (FTURLSessionAutoInstrumentation *)sessionInstrumentation{
    if(!_sessionInstrumentation){
        _sessionInstrumentation = [[FTURLSessionAutoInstrumentation alloc]init];
    }
    return _sessionInstrumentation;
}
- (void)startTraceWithConfigOptions:(FTTraceConfig *)traceConfigOptions{
    [self.sessionInstrumentation setTraceConfig:traceConfigOptions];
    [FTExternalDataManager sharedManager].traceDelegate = self.sessionInstrumentation.tracer;
    [FTExternalDataManager sharedManager].resourceDelegate = self.sessionInstrumentation.rumResourceHandler;

}
-(void)logging:(NSString *)content status:(FTLogStatus)status{
    if (![content isKindOfClass:[NSString class]] || content.length==0) {
        return;
    }
    NSString *bundleIdentifier =  [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"];
    
    NSMutableDictionary *tagDict = @{
        @"extension_identifier":bundleIdentifier,
    }.mutableCopy;
    if (self.loggerConfig.enableLinkRumData) {
        NSDictionary *rumTag = [self.rumManager getCurrentSessionInfo];
        [tagDict addEntriesFromDictionary:rumTag];
    }

    ZYDebug(@"%@\n",@{@"type":FT_LOGGER_SOURCE,
                      @"tags":tagDict,
                      @"content":content
                    });
    [[FTExtensionDataManager sharedInstance] writeLoggerEvent:(int)status content:content tags:tagDict fields:nil tm:[FTDateUtil currentTimeNanosecond] groupIdentifier:self.extensionConfig.groupIdentifier];
}

- (void)rumWrite:(NSString *)type terminal:(NSString *)terminal tags:(NSDictionary *)tags fields:(NSDictionary *)fields{
    [self rumWrite:type terminal:terminal tags:tags fields:fields tm:[FTDateUtil currentTimeNanosecond]];
}
- (void)rumWrite:(NSString *)type terminal:(NSString *)terminal tags:(NSDictionary *)tags fields:(NSDictionary *)fields tm:(long long)tm{
    NSString *bundleIdentifier =  [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"];
    NSMutableDictionary *newTags = @{
          @"extension_identifier":bundleIdentifier,
    }.mutableCopy;
    if(tags){
        [newTags addEntriesFromDictionary:tags];
    }
    ZYDebug(@"%@\n",@{@"type":type,
                    @"tags":newTags,
                    @"fields":fields});
    [[FTExtensionDataManager sharedInstance] writeRumEventType:type tags:newTags fields:fields tm:tm groupIdentifier:self.extensionConfig.groupIdentifier];
}
@end
