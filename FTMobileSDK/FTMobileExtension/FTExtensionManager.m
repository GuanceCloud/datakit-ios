//
//  FTExtensionManager.m
//  FTMobileExtension
//
//  Created by hulilei on 2020/11/13.
//  Copyright © 2020 hll. All rights reserved.
//

#import "FTExtensionManager.h"
#import "FTExtensionDataManager.h"
#import "FTCrash.h"
#import "FTLog+Private.h"
#import "FTRUMManager.h"
#import "FTRUMDataWriteProtocol.h"
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
@end
@implementation FTExtensionManager
static FTExtensionManager *sharedInstance = nil;
+ (instancetype)sharedInstance{
    NSAssert(sharedInstance, @"Please initialize with startWithExtensionConfig: first");
    return sharedInstance;
}
+ (void)startWithExtensionConfig:(FTExtensionConfig *)extensionConfig{
    NSAssert((extensionConfig.groupIdentifier.length!=0 ), @"Please fill in Group Identifier");
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[FTExtensionManager alloc]initWithExtensionConfig:extensionConfig];
    });
}
-(instancetype)initWithExtensionConfig:(FTExtensionConfig *)extensionConfig{
    self = [super init];
    if (self) {
        _extensionConfig = [extensionConfig copy];
        [FTLog enableLog:_extensionConfig.enableSDKDebugLog];
        [FTExtensionDataManager sharedInstance].maxCount = _extensionConfig.memoryMaxCount;
        [self processingConfigItems];
    }
    return self;
}
- (void)processingConfigItems{
    NSDictionary *mobileDict = [[FTExtensionDataManager sharedInstance] getMobileConfigWithGroupIdentifier:self.extensionConfig.groupIdentifier];
    NSDictionary *rumDict = [[FTExtensionDataManager sharedInstance] getRumConfigWithGroupIdentifier:self.extensionConfig.groupIdentifier];
    NSDictionary *traceDict = [[FTExtensionDataManager sharedInstance] getTraceConfigWithGroupIdentifier:self.extensionConfig.groupIdentifier];
    NSDictionary *loggerDict = [[FTExtensionDataManager sharedInstance] getLoggerConfigWithGroupIdentifier:self.extensionConfig.groupIdentifier];
   
    FTMobileConfig *mobileConfig = [[FTMobileConfig alloc]initWithDictionary:mobileDict];
    FTRumConfig *rumConfig =[[FTRumConfig alloc]initWithDictionary:rumDict];
    FTTraceConfig *traceConfig =[[FTTraceConfig alloc]initWithDictionary:traceDict];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]initWithDictionary:loggerDict];
    if(mobileConfig){
        [[FTURLSessionInstrumentation sharedInstance] setSdkUrlStr:mobileConfig.datakitUrl.length>0?mobileConfig.datakitUrl:mobileConfig.datawayUrl serviceName:mobileConfig.service];
    }
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
        [[FTLogger sharedInstance] startWithLoggerConfig:loggerConfig writer:self];
        [FTLogger sharedInstance].linkRumDataProvider = self.rumManager;
    }
}
- (void)startRumWithConfigOptions:(FTRumConfig *)rumConfigOptions{
    [[FTURLSessionInstrumentation sharedInstance]setEnableAutoRumTrace:rumConfigOptions.enableTraceUserResource
                                                    resourceUrlHandler:rumConfigOptions.resourceUrlHandler
                                              resourcePropertyProvider:rumConfigOptions.resourcePropertyProvider
                                                sessionTaskErrorFilter:rumConfigOptions.sessionTaskErrorFilter
    ];
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
        [[FTCrash shared] addErrorDataDelegate:self.rumManager];
    }
    [[FTURLSessionInstrumentation sharedInstance] setRumResourceHandler:self.rumManager];
}

- (void)startTraceWithConfigOptions:(FTTraceConfig *)traceConfigOptions{
    [[FTURLSessionInstrumentation sharedInstance] setTraceEnableAutoTrace:traceConfigOptions.enableAutoTrace enableLinkRumData:traceConfigOptions.enableLinkRumData sampleRate:traceConfigOptions.samplerate traceType:traceConfigOptions.networkTraceType traceInterceptor:traceConfigOptions.traceInterceptor];
    [FTExternalDataManager sharedManager].resourceDelegate = [FTURLSessionInstrumentation sharedInstance].externalResourceHandler;

}
-(void)logging:(NSString *)content status:(FTLogStatus)status{
    [self logging:content status:status property:nil];
}
-(void)logging:(NSString *)content status:(FTLogStatus)status property:(nullable NSDictionary *)property{
    if (![content isKindOfClass:[NSString class]] || content.length==0) {
        return;
    }
    [[FTLogger sharedInstance] log:content statusType:status property:property];
}
-(void)logging:(NSString *)content status:(NSString *)status tags:(NSDictionary *)tags field:(NSDictionary *)field time:(long long)time{
    @try {
        NSString *newContent = [content ft_subStringWithCharacterLength:FT_LOGGING_CONTENT_SIZE];
        NSString *bundleIdentifier =  [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"];
        if (bundleIdentifier == nil) {
            return;
        }
        NSMutableDictionary *tagDict = [NSMutableDictionary new];
        [tags setValue:bundleIdentifier forKey:@"extension_identifier"];
        [tagDict addEntriesFromDictionary:tags];
        FTInnerLogDebug(@"%@\n",@{@"type":FT_LOGGER_SOURCE,
                                  @"tags":tagDict,
                                  @"content":newContent?:@"",
                                });
        [[FTExtensionDataManager sharedInstance] writeLoggerEvent:status content:newContent tags:tagDict fields:nil tm:time groupIdentifier:self.extensionConfig.groupIdentifier];
    } @catch (NSException *exception) {
        FTInnerLogError(@"exception %@",exception);
    }
}
- (void)rumWrite:(NSString *)type tags:(NSDictionary *)tags fields:(NSDictionary *)fields time:(long long)time{
    NSString *bundleIdentifier =  [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"];
    NSMutableDictionary *tagDict = [NSMutableDictionary new];
    [tagDict setValue:bundleIdentifier forKey:@"extension_identifier"];
    [tagDict addEntriesFromDictionary:tags];
    FTInnerLogDebug(@"%@\n",@{@"type":type?:@"",
                              @"tags":tagDict,
                              @"fields":fields});
    [[FTExtensionDataManager sharedInstance] writeRumEventType:type tags:tagDict fields:fields tm:time groupIdentifier:self.extensionConfig.groupIdentifier];
}
@end
