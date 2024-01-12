//
//  FTUncaughtExceptionHandler.m
//  FTAutoTrack
//
//  Created by 胡蕾蕾 on 2020/1/6.
//  Copyright © 2020 hll. All rights reserved.
//
#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif
#import "FTCrashMonitor.h"
#import "FTCallStack.h"
#import "FTNSException.h"
#include "FTSignalException.h"
#include "FTMachException.h"

@interface FTCrashMonitor()
@property (nonatomic, strong) NSHashTable *ftSDKInstances;
@end
@implementation FTCrashMonitor
void crashNotifyCallback(thread_t thread,uintptr_t*backtrace,int count,const char *crashMessage){
    FTUninstallSignalException();
    FTUninstallUncaughtExceptionHandler();
    FTUninstallMachException();
    NSString *stackInfo = [FTCallStack ft_reportOfThread:thread backtrace:backtrace count:count];
    for (id instance in FTCrashMonitor.shared.ftSDKInstances) {
        if ([instance respondsToSelector:@selector(internalErrorWithType:message:stack:)]) {
            [instance internalErrorWithType:@"ios_crash" message:[NSString stringWithCString:crashMessage encoding:NSUTF8StringEncoding] stack:stackInfo];
        }
    }
}
+ (instancetype)shared {
    static FTCrashMonitor *sharedHandler = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedHandler = [[FTCrashMonitor alloc] init];
    });
    return sharedHandler;
}
- (instancetype)init {
    self = [super init];
    if (self) {
        _ftSDKInstances = [NSHashTable weakObjectsHashTable];
        // Install our handler
        FTInstallUncaughtExceptionHandler(crashNotifyCallback);
        FTInstallSignalException(crashNotifyCallback);
        FTInstallMachException(crashNotifyCallback);
    }
    return self;
}
- (void)addErrorDataDelegate:(id <FTErrorDataDelegate>)instance{
    NSParameterAssert(instance != nil);
    if (![self.ftSDKInstances containsObject:instance]) {
        [self.ftSDKInstances addObject:instance];
    }
}
- (void)removeErrorDataDelegate:(id <FTErrorDataDelegate>)instance{
    NSParameterAssert(instance != nil);
    if ([self.ftSDKInstances containsObject:instance]) {
        [self.ftSDKInstances removeObject:instance];
    }
}
@end
