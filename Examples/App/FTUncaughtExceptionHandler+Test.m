//
//  FTUncaughtExceptionHandler+Test.m
//  FTMobileSDKUITests
//
//  Created by hulilei on 2020/9/21.
//  Copyright © 2020 hll. All rights reserved.
//

#import "FTUncaughtExceptionHandler+Test.h"
#import <UIKit/UIKit.h>
#include <execinfo.h>
#import <objc/runtime.h>
//#import <FTConstants.h>
//#import <FTMobileAgent/FTBaseInfoHandler.h>
#import <os/log.h>
@implementation FTUncaughtExceptionHandler (Test)
- (void)handleException:(NSException *)exception {
    NSString *info = [self handleExceptionInfo:exception];
   
    os_log(OS_LOG_DEFAULT, "[FTLog][Crash]%{public}@", info);

    
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
    UIWindow *window = [FTUncaughtExceptionHandler keyWindow];
    UIViewController  *tabSelectVC = ((UITabBarController*)window.rootViewController).selectedViewController;
    UIViewController *vc =      ((UINavigationController*)tabSelectVC).viewControllers.lastObject;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Crash" message:info preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *action = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        testSuccess = YES;
    }];
    [alert addAction:action];
    [vc presentViewController:alert animated:YES completion:nil];
    //Get MainRunloop
    CFRunLoopRef runLoop = CFRunLoopGetCurrent();
    CFArrayRef allModes = CFRunLoopCopyAllModes(runLoop);
    while (!testSuccess){  //Use testSuccess flag to determine whether to continue blocking the thread, can modify testSuccess value after operation is completed.
        for (NSString *mode in (__bridge NSArray *)allModes) {
            CFRunLoopRunInMode((CFStringRef)mode, 0.001, false);
        }
    }
    //Release objects
    CFRelease(allModes);
}
+ (UIWindow *)keyWindow{
    UIWindow  *foundWindow = nil;
    NSArray   *windows = [[UIApplication sharedApplication]windows];
    for (UIWindow *window in windows) {
        if (window.isKeyWindow) {
            foundWindow = window;
            break;
        }
    }
    return foundWindow;
}
@end


