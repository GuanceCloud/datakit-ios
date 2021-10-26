//
//  FTUncaughtExceptionHandler+Test.m
//  FTMobileSDKUITests
//
//  Created by 胡蕾蕾 on 2020/9/21.
//  Copyright © 2020 hll. All rights reserved.
//

#import "FTUncaughtExceptionHandler+Test.h"
#import <FTMobileAgent/FTMobileAgent.h>
#import <FTMonitorManager.h>
#include <execinfo.h>
#import <objc/runtime.h>
#import <FTMobileAgent/FTConstants.h>
#import <FTMobileAgent/FTBaseInfoHandler.h>
#import <FTRUMManager.h>
@implementation FTUncaughtExceptionHandler (Test)
- (void)handleException:(NSException *)exception {
    NSString *info = @"";
    long slide_address = [FTUncaughtExceptionHandler ft_calculateImageSlide];
    info =[NSString stringWithFormat:@"Slide_Address:%ld\nException Stack:\n%@", slide_address,exception.userInfo[@"UncaughtExceptionHandlerAddressesKey"]];
    //            NSNumber *crashDate =@([[NSDate date] ft_dateTimestamp]);
    NSDictionary *field = @{ @"error_message":[exception reason],
                             @"error_stack":info,
    };
    NSString *run = [FTMonitorManager sharedInstance].running?@"run":@"startup";
    NSDictionary *tags = @{
        @"error_type":[exception name],
        @"error_source":@"logger",
        @"crash_situation":run
    };
    [[FTMonitorManager sharedInstance].rumManger addError:tags field:field];
    
    NSSetUncaughtExceptionHandler(NULL);
    signal(SIGSEGV,SIG_DFL);
    signal(SIGFPE,SIG_DFL);
    signal(SIGBUS,SIG_DFL);
    signal(SIGTRAP,SIG_DFL);
    signal(SIGABRT,SIG_DFL);
    signal(SIGILL,SIG_DFL);
    signal(SIGPIPE,SIG_DFL);
    signal(SIGSYS,SIG_DFL);
    __block BOOL testSuccess = NO;
    UIWindow *window = [FTBaseInfoHandler keyWindow];
    UIViewController  *tabSelectVC = ((UITabBarController*)window.rootViewController).selectedViewController;
    UIViewController *vc =      ((UINavigationController*)tabSelectVC).viewControllers.lastObject;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Crash" message:info preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *action = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        testSuccess = YES;
    }];
    [alert addAction:action];
    [vc presentViewController:alert animated:YES completion:nil];
    //获取MainRunloop
    CFRunLoopRef runLoop = CFRunLoopGetCurrent();
    CFArrayRef allModes = CFRunLoopCopyAllModes(runLoop);
    while (!testSuccess){  //根据testSuccess标记来判断当前是否需要继续卡死线程，可以在操作完成后修改testSuccess的值。
        for (NSString *mode in (__bridge NSArray *)allModes) {
            CFRunLoopRunInMode((CFStringRef)mode, 0.001, false);
        }
    }
    //释放对象
    CFRelease(allModes);
}

@end


