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
@interface FTExtensionManager ()<FTRUMDataWriteProtocol>
@property (nonatomic, copy) NSString *groupIdentifer;
@property (nonatomic, strong) FTRUMManager *rumManager;
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
        [[FTUncaughtExceptionHandler sharedHandler] addftSDKInstance:self.rumManager];
    }
    return self;
}
- (void)startRumWithConfigOptions:(FTRumConfig *)rumConfigOptions{
    
}
- (void)startTraceWithConfigOptions:(FTTraceConfig *)traceConfigOptions{
    
}
- (void)rumWrite:(NSString *)type terminal:(NSString *)terminal tags:(NSDictionary *)tags fields:(NSDictionary *)fields{
    [[FTExtensionDataManager sharedInstance] writeEventType:type tags:tags fields:fields tm:[FTDateUtil currentTimeNanosecond] groupIdentifier:self.groupIdentifer];
}
- (void)rumWrite:(NSString *)type terminal:(NSString *)terminal tags:(NSDictionary *)tags fields:(NSDictionary *)fields tm:(long long)tm{
    [[FTExtensionDataManager sharedInstance] writeEventType:type tags:tags fields:fields tm:tm groupIdentifier:self.groupIdentifer];
}

+ (void)enableLog:(BOOL)enable{
    [FTLog enableLog:enable];
}
@end
