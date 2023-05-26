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
#import "FTInternalLog.h"
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
#import "FTEnumConstant.h"
@interface FTExtensionManager ()<FTRUMDataWriteProtocol>
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
        [FTInternalLog enableLog:extensionConfig.enableSDKDebugLog];
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
    self.loggerConfig = loggerConfig;
}
- (void)startRumWithConfigOptions:(FTRumConfig *)rumConfigOptions{
    [[FTURLSessionAutoInstrumentation sharedInstance] setRUMEnableTraceUserResource:rumConfigOptions.enableTraceUserResource];
    self.rumManager = [[FTRUMManager alloc] initWithRumSampleRate:rumConfigOptions.samplerate errorMonitorType:(ErrorMonitorType)rumConfigOptions.errorMonitorType monitor:nil wirter:self];
    self.rumManager.appState = AppStateUnknown;
    id <FTRumDatasProtocol> rum = self.rumManager;
    [[FTExternalDataManager sharedManager] setDelegate:rum];
    [FTExternalDataManager sharedManager].resourceDelegate = [FTURLSessionAutoInstrumentation sharedInstance].externalResourceHandler;
    if (rumConfigOptions.enableTrackAppCrash){
        [[FTUncaughtExceptionHandler sharedHandler] addErrorDataDelegate:self.rumManager];
    }
    [[FTURLSessionAutoInstrumentation sharedInstance] setRumResourceHandler:self.rumManager];
}

- (void)startTraceWithConfigOptions:(FTTraceConfig *)traceConfigOptions{
    [[FTURLSessionAutoInstrumentation sharedInstance] setTraceEnableAutoTrace:traceConfigOptions.enableAutoTrace enableLinkRumData:traceConfigOptions.enableLinkRumData sampleRate:traceConfigOptions.samplerate traceType:(NetworkTraceType)traceConfigOptions.networkTraceType];
    [FTExternalDataManager sharedManager].resourceDelegate = [FTURLSessionAutoInstrumentation sharedInstance].externalResourceHandler;

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

    ZYLogDebug(@"%@\n",@{@"type":FT_LOGGER_SOURCE,
                      @"tags":tagDict,
                      @"content":content
                    });
    [[FTExtensionDataManager sharedInstance] writeLoggerEvent:(int)status content:content tags:tagDict fields:nil tm:[FTDateUtil currentTimeNanosecond] groupIdentifier:self.extensionConfig.groupIdentifier];
}

- (void)rumWrite:(NSString *)type  tags:(NSDictionary *)tags fields:(NSDictionary *)fields{
    [self rumWrite:type tags:tags fields:fields tm:[FTDateUtil currentTimeNanosecond]];
}
- (void)rumWrite:(NSString *)type tags:(NSDictionary *)tags fields:(NSDictionary *)fields tm:(long long)tm{
    NSString *bundleIdentifier =  [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"];
    NSMutableDictionary *newTags = @{
          @"extension_identifier":bundleIdentifier,
    }.mutableCopy;
    if(tags){
        [newTags addEntriesFromDictionary:tags];
    }
    ZYLogDebug(@"%@\n",@{@"type":type,
                    @"tags":newTags,
                    @"fields":fields});
    [[FTExtensionDataManager sharedInstance] writeRumEventType:type tags:newTags fields:fields tm:tm groupIdentifier:self.extensionConfig.groupIdentifier];
}
@end
