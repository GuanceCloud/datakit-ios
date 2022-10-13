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
#import "URLSessionAutoInstrumentation.h"
#import "FTTracer.h"
#import "FTExternalDataManager+Private.h"
#import "FTBaseInfoHandler.h"
#import "NSString+FTAdd.h"
#import "FTConstants.h"
#import "FTMobileConfig.h"
@interface FTExtensionManager ()<FTRUMDataWriteProtocol>
@property (nonatomic, copy) NSString *groupIdentifer;
@property (nonatomic, strong) FTRUMManager *rumManager;
@property (nonatomic, strong) URLSessionAutoInstrumentation *sessionInstrumentation;
@property (nonatomic, strong) FTTracer *tracer;
@property (nonatomic, strong) FTLoggerConfig *loggerConfig;
@property (nonatomic, strong) NSSet *logLevelFilterSet;
@end
@implementation FTExtensionManager
static FTExtensionManager *sharedInstance = nil;
+ (instancetype)sharedInstance{
    NSAssert(sharedInstance, @"请先使用 startWithApplicationGroupIdentifier: 初始化");
    return sharedInstance;
}
+ (void)startWithApplicationGroupIdentifier:(NSString *)groupIdentifer{
    NSAssert((groupIdentifer.length!=0 ), @"请填写Group Identifier");
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[FTExtensionManager alloc]initWithGroupIdentifier:groupIdentifer];
    });
}
-(instancetype)initWithGroupIdentifier:(NSString *)identifier{
    self = [super init];
    if (self) {
        _groupIdentifer = identifier;
    }
    return self;
}
- (void)startRumWithConfigOptions:(FTRumConfig *)rumConfigOptions{
    [self.sessionInstrumentation setRUMConfig:rumConfigOptions];
    self.rumManager = [[FTRUMManager alloc] initWithRumConfig:rumConfigOptions monitor:nil wirter:self];
    id <FTAddRumDatasProtocol> rum = self.rumManager;
    [[FTExternalDataManager sharedManager] setDelegate:rum];
    
    if (rumConfigOptions.enableTrackAppCrash){
        [[FTUncaughtExceptionHandler sharedHandler] addftSDKInstance:self.rumManager];
    }
    self.sessionInstrumentation.interceptor.innerResourceHandeler = self.rumManager;
}
- (URLSessionAutoInstrumentation *)sessionInstrumentation{
    if(!_sessionInstrumentation){
        _sessionInstrumentation = [[URLSessionAutoInstrumentation alloc]init];
    }
    return _sessionInstrumentation;
}
- (void)startTraceWithConfigOptions:(FTTraceConfig *)traceConfigOptions{
    self.tracer = [[FTTracer alloc]initWithConfig:traceConfigOptions];
    [self.sessionInstrumentation setTraceConfig:traceConfigOptions tracer:self.tracer];
    [FTExternalDataManager sharedManager].traceDelegate = self.tracer;
    [FTExternalDataManager sharedManager].resourceDelegate = self.sessionInstrumentation.rumResourceHandler;

}
- (void)startLoggerWithConfigOptions:(FTLoggerConfig *)loggerConfigOptions{
    self.loggerConfig = [loggerConfigOptions copy];
    self.logLevelFilterSet = [NSSet setWithArray:self.loggerConfig.logLevelFilter];
}
-(void)logging:(NSString *)content status:(FTLogStatus)status{
    if (![content isKindOfClass:[NSString class]] || content.length==0) {
        return;
    }
    if (!self.loggerConfig) {
        ZYErrorLog(@"请先设置 FTLoggerConfig");
        return;
    }
    if (!content || content.length == 0 || [content ft_characterNumber]>FT_LOGGING_CONTENT_SIZE) {
        ZYErrorLog(@"传入的第数据格式有误，或content超过30kb");
        return;
    }
    if (![self.logLevelFilterSet containsObject:@(status)]) {
        ZYDebug(@"经过过滤算法判断-此条日志不采集");
        return;
    }
    if (![FTBaseInfoHandler randomSampling:self.loggerConfig.samplerate]){
        ZYDebug(@"经过采集算法判断-此条日志不采集");
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
                    @"tags":tagDict});
    [[FTExtensionDataManager sharedInstance] writeLoggerEvent:(int)status content:content tags:tagDict fields:nil tm:[FTDateUtil currentTimeNanosecond] groupIdentifier:self.groupIdentifer];
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
    [[FTExtensionDataManager sharedInstance] writeRumEventType:type tags:newTags fields:fields tm:tm groupIdentifier:self.groupIdentifer];
}
+ (void)enableLog:(BOOL)enable{
    [FTLog enableLog:enable];
}
@end
