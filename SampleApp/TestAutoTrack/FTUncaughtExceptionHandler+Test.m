//
//  FTUncaughtExceptionHandler+Test.m
//  FTMobileSDKUITests
//
//  Created by 胡蕾蕾 on 2020/9/21.
//  Copyright © 2020 hll. All rights reserved.
//

#import "FTUncaughtExceptionHandler+Test.h"
#import <FTMobileAgent/FTMobileAgent.h>
#import <FTMobileAgent/NSDate+FTAdd.h>
#import <FTMobileAgent/FTMobileAgent+Private.h>
#include <execinfo.h>
#import <objc/runtime.h>
typedef void(*SignalHandler2)(int signal, siginfo_t *info, void *context);

@implementation FTUncaughtExceptionHandler (Test)
-(BOOL)testSuccess{
    return [objc_getAssociatedObject(self, @"testSuccess") boolValue];
}

-(void)setTestSuccess:(BOOL)testSuccess{
    objc_setAssociatedObject(self, @"testSuccess", [NSNumber numberWithBool:testSuccess], OBJC_ASSOCIATION_ASSIGN);
}
void HandleException2(NSException *exception) {
    
    NSString *exceptionStack = [[exception callStackSymbols] componentsJoinedByString:@"\n"];
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithDictionary:[exception userInfo]];
    [userInfo setObject:exceptionStack forKey:@"UncaughtExceptionHandlerAddressesKey"];
    
    //在主线程中，执行制定的方法, withObject是执行方法传入的参数
    [[FTUncaughtExceptionHandler sharedHandler]
     performSelector:@selector(handleException:) onThread:[NSThread currentThread] withObject:[NSException exceptionWithName:[exception name]
                                                                                                                      reason:[exception reason]
                                                                                                                    userInfo:userInfo]
     waitUntilDone:YES];

}
- (void)handleException:(NSException *)exception {
    
    NSString *info=[NSString stringWithFormat:@"Exception Reason:%@\nException Stack:\n%@\ndSYMUUID:%@", [exception reason], exception.userInfo[@"UncaughtExceptionHandlerAddressesKey"],[self getUUIDDictionary]];
    ;
    for (FTMobileAgent *instance in self.ftSDKInstances) {
        [instance _loggingExceptionInsertWithContent:info tm:[[NSDate date] ft_dateTimestamp]];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window;
           if (@available(iOS 13.0, *)) {
                    for (UIWindowScene* windowScene in [UIApplication sharedApplication].connectedScenes)
                    {
                        if (windowScene.activationState == UISceneActivationStateForegroundActive)
                        {
                            window = windowScene.windows.firstObject;
                            break;
                        }
                    }
                }else{
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
                    // 这部分使用到的过期api
                    window = [UIApplication sharedApplication].keyWindow;
        #pragma clang diagnostic pop
                }
        UIViewController  *tabSelectVC = ((UITabBarController*)window.rootViewController).selectedViewController;
         UIViewController *vc =      ((UINavigationController*)tabSelectVC).viewControllers.lastObject;
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Crash" message:info preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *action = [UIAlertAction actionWithTitle:@"cancle" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
            
        }];
        UIAlertAction *action2 = [UIAlertAction actionWithTitle:@"crash" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [FTUncaughtExceptionHandler sharedHandler].testSuccess = YES;
        }];
        [alert addAction:action];
        [alert addAction:action2];
        [vc presentViewController:alert animated:YES completion:nil];
              
    });
    
    //获取MainRunloop
    CFRunLoopRef runLoop = CFRunLoopGetCurrent();
    CFArrayRef allModes = CFRunLoopCopyAllModes(runLoop);
    while (!self.testSuccess){  //根据testSuccess标记来判断当前是否需要继续卡死线程，可以在操作完成后修改testSuccess的值。
        for (NSString *mode in (__bridge NSArray *)allModes) {
            CFRunLoopRunInMode((CFStringRef)mode, 0.001, false);
        }
    }
    //释放对象
    CFRelease(allModes);
   
}
- (void)installUncaughtExceptionHandler{
    NSSetUncaughtExceptionHandler(&HandleException2);
    
}
- (void)installSignalHandler{
    struct sigaction action;
    action.sa_sigaction = FTSignalHandler2;
    action.sa_flags = SA_NODEFER | SA_SIGINFO;
    sigemptyset(&action.sa_mask);
    int signals[] = {SIGABRT,SIGBUS, SIGFPE, SIGILL, SIGPIPE, SIGSEGV,SIGSYS,SIGTRAP};
    for (int i = 0; i < sizeof(signals) / sizeof(int); i++) {
        sigaction(signals[i], &action, 0);
    }
}
static void FTSignalHandler2(int signal1, siginfo_t* info, void* context) {
        NSString* description = nil;
        switch (signal1) {
            case SIGABRT:
                description = [NSString stringWithFormat:@"Signal SIGABRT was raised!\n"];
                break;
            case SIGILL:
                description = [NSString stringWithFormat:@"Signal SIGILL was raised!\n"];
                break;
            case SIGSEGV:
                description = [NSString stringWithFormat:@"Signal SIGSEGV was raised!\n"];
                break;
            case SIGFPE:
                description = [NSString stringWithFormat:@"Signal SIGFPE was raised!\n"];
                break;
            case SIGBUS:
                description = [NSString stringWithFormat:@"Signal SIGBUS was raised!\n"];
                break;
            case SIGPIPE:
                description = [NSString stringWithFormat:@"Signal SIGPIPE was raised!\n"];
                break;
            default:
                description = [NSString stringWithFormat:@"Signal %d was raised!",signal1];
        }
        // 保存崩溃日志
        NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
        NSArray *callStack = [FTUncaughtExceptionHandler backtrace];
        NSString *exceptionStack = [callStack componentsJoinedByString:@"\n"];
        [userInfo setObject:exceptionStack forKey:@"UncaughtExceptionHandlerAddressesKey"];
        [userInfo setObject:[NSNumber numberWithInt:signal1] forKey:@"UncaughtExceptionHandlerSignalKey"];
        @try {
            [[FTUncaughtExceptionHandler sharedHandler]
             performSelector:@selector(handleException:) onThread:[NSThread currentThread] withObject:
             [NSException exceptionWithName:@"UncaughtExceptionHandlerSignalExceptionName" reason:description userInfo:userInfo]
             waitUntilDone:YES];
        } @catch (NSException *exception) {
      
        
    }
       
    signal(SIGSEGV,SIG_DFL);
    signal(SIGFPE,SIG_DFL);
    signal(SIGBUS,SIG_DFL);
    signal(SIGTRAP,SIG_DFL);
    signal(SIGABRT,SIG_DFL);
    signal(SIGILL,SIG_DFL);
    signal(SIGPIPE,SIG_DFL);
    signal(SIGSYS,SIG_DFL);
    kill(getpid(), SIGKILL);
}
@end


