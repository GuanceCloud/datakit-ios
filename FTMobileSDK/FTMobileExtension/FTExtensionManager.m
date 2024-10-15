//
//  FTExtensionManager.m
//  FTMobileExtension
//
//  Created by 胡蕾蕾 on 2020/11/13.
//  Copyright © 2020 hll. All rights reserved.
//

#import "FTExtensionManager.h"
#import "FTExtensionDataManager.h"
#import "FTCrashMonitor.h"
#import "FTLog+Private.h"
#import "FTRUMManager.h"
#import "FTRUMDataWriteProtocol.h"
#import "FTMobileConfig.h"
#import "FTURLSessionInstrumentation.h"
#import "FTTracer.h"
#import "FTExternalDataManager+Private.h"
#import "FTBaseInfoHandler.h"
#import "NSString+FTAdd.h"
#import "FTConstants.h"
#import "FTMobileConfig+Private.h"
#import "FTEnumConstant.h"
#import "FTLogger+Private.h"
@interface FTExtensionManager ()<FTRUMDataWriteProtocol,FTLoggerDataWriteProtocol>
@property (nonatomic, strong) FTRUMManager *rumManager;
@property (nonatomic, strong) FTLoggerConfig *loggerConfig;
@property (nonatomic, strong) FTExtensionConfig *extensionConfig;
@property (nonatomic, strong) NSSet *logLevelFilterSet;
@end
@implementation FTExtensionManager
static FTExtensionManager *sharedInstance = nil;
+ (instancetype)sharedInstance{
    NSAssert(sharedInstance, @"请先使用 startWithExtensionConfig: 初始化");
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
        [FTExtensionDataManager sharedInstance].maxCount = extensionConfig.memoryMaxCount;
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
        rumConfig.enableTraceUserResource = self.extensionConfig.enableRUMAutoTraceResource;
        rumConfig.enableTrackAppCrash = self.extensionConfig.enableTrackAppCrash;
        [self startRumWithConfigOptions:rumConfig];
    }
    if(traceConfig){
        traceConfig.enableAutoTrace = self.extensionConfig.enableTracerAutoTrace;
        [self startTraceWithConfigOptions:traceConfig];
    }
    if(loggerConfig){
        self.loggerConfig = loggerConfig;
        self.logLevelFilterSet = [NSSet setWithArray:loggerConfig.logLevelFilter];
        [FTLogger startWithEnablePrintLogsToConsole:loggerConfig.printCustomLogToConsole enableCustomLog:loggerConfig.enableCustomLog
                                  enableLinkRumData:loggerConfig.enableLinkRumData
                                     logLevelFilter:loggerConfig.logLevelFilter sampleRate:loggerConfig.samplerate writer:self];
        [FTLogger sharedInstance].linkRumDataProvider = self.rumManager;
    }
}
- (void)startRumWithConfigOptions:(FTRumConfig *)rumConfigOptions{
    [[FTURLSessionInstrumentation sharedInstance] setEnableAutoRumTrace:rumConfigOptions.enableTraceUserResource resourceUrlHandler:rumConfigOptions.resourceUrlHandler];
    FTRUMDependencies *dependencies = [[FTRUMDependencies alloc]init];
    dependencies.writer = self;
    dependencies.errorMonitorType = (ErrorMonitorType)rumConfigOptions.errorMonitorType;
    dependencies.sampleRate = rumConfigOptions.samplerate;
    self.rumManager = [[FTRUMManager alloc] initWithRumDependencies:dependencies];
    self.rumManager.appState = FTAppStateUnknown;
    id <FTRumDatasProtocol> rum = self.rumManager;
    [[FTExternalDataManager sharedManager] setDelegate:rum];
    [FTExternalDataManager sharedManager].resourceDelegate = [FTURLSessionInstrumentation sharedInstance].externalResourceHandler;
    if (rumConfigOptions.enableTrackAppCrash){
        [[FTCrashMonitor shared] addErrorDataDelegate:self.rumManager];
    }
    [[FTURLSessionInstrumentation sharedInstance] setRumResourceHandler:self.rumManager];
}

- (void)startTraceWithConfigOptions:(FTTraceConfig *)traceConfigOptions{
    [[FTURLSessionInstrumentation sharedInstance] setTraceEnableAutoTrace:traceConfigOptions.enableAutoTrace enableLinkRumData:traceConfigOptions.enableLinkRumData sampleRate:traceConfigOptions.samplerate traceType:traceConfigOptions.networkTraceType];
    [FTExternalDataManager sharedManager].resourceDelegate = [FTURLSessionInstrumentation sharedInstance].externalResourceHandler;

}
-(void)logging:(NSString *)content status:(FTLogStatus)status{
    [self logging:content status:status property:nil];
}
-(void)logging:(NSString *)content status:(FTLogStatus)status property:(nullable NSDictionary *)property{
    if (![content isKindOfClass:[NSString class]] || content.length==0) {
        return;
    }
    [[FTLogger sharedInstance] log:content statusType:(LogStatus)status property:property];
}
-(void)logging:(NSString *)content status:(NSString *)status tags:(NSDictionary *)tags field:(NSDictionary *)field time:(long long)time{
    @try {
        NSString *newContent = [content ft_subStringWithCharacterLength:FT_LOGGING_CONTENT_SIZE];
        NSString *bundleIdentifier =  [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"];
        
        NSMutableDictionary *tagDict = @{
            @"extension_identifier":bundleIdentifier,
        }.mutableCopy;
        [tagDict addEntriesFromDictionary:tags];
        FTInnerLogDebug(@"%@\n",@{@"type":FT_LOGGER_SOURCE,
                             @"tags":tagDict,
                             @"content":newContent
                           });
        [[FTExtensionDataManager sharedInstance] writeLoggerEvent:status content:newContent tags:tagDict fields:nil tm:time groupIdentifier:self.extensionConfig.groupIdentifier];
    } @catch (NSException *exception) {
        FTInnerLogError(@"exception %@",exception);
    }
}
- (void)rumWrite:(NSString *)type tags:(NSDictionary *)tags fields:(NSDictionary *)fields time:(long long)time{
    NSString *bundleIdentifier =  [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"];
    NSMutableDictionary *newTags = @{
        @"extension_identifier":bundleIdentifier,
    }.mutableCopy;
    if(tags){
        [newTags addEntriesFromDictionary:tags];
    }
    FTInnerLogDebug(@"%@\n",@{@"type":type,
                              @"tags":newTags,
                              @"fields":fields});
    [[FTExtensionDataManager sharedInstance] writeRumEventType:type tags:newTags fields:fields tm:time groupIdentifier:self.extensionConfig.groupIdentifier];
}
@end
