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
#import "FTLog.h"
@interface FTExtensionManager ()<FTErrorDataDelegate>
@property (nonatomic, copy) NSString *groupIdentifer;
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
        [[FTUncaughtExceptionHandler sharedHandler] addftSDKInstance:self];
    }
    return self;
}
-(void)addErrorWithType:(NSString *)type message:(NSString *)message stack:(NSString *)stack{
    NSDictionary *field = @{ @"error_message":message,
                             @"error_stack":stack,
    };
    NSDictionary *tags = @{
        @"error_type":type,
        @"error_source":@"logger",
    };
    [[FTExtensionDataManager sharedInstance] writeEventType:@"error" tags:tags fields:field groupIdentifier:self.groupIdentifer];
}
+ (void)enableLog:(BOOL)enable{
    [FTLog enableLog:enable];
}
@end
