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
#import <FTMobileAgent/FTConstants.h>
#import <FTMobileAgent/FTBaseInfoHander.h>
@implementation FTUncaughtExceptionHandler (Test)
- (void)handleException:(NSException *)exception {
    long slide_address = [FTUncaughtExceptionHandler ft_calculateImageSlide];
    NSString *info=[NSString stringWithFormat:@"Exception Reason:%@\nSlide_Address:%ld\nException Stack:\n%@\n", [exception reason],slide_address, exception.userInfo[@"UncaughtExceptionHandlerAddressesKey"]];
    for (FTMobileAgent *instance in self.ftSDKInstances) {
        NSDictionary *field =  @{FT_KEY_EVENT:@"crash"};
       
        [instance _loggingExceptionInsertWithContent:info tm:[[NSDate date] ft_dateTimestamp]];
    }
   __block BOOL testSuccess = NO;
    UIWindow *window = [FTBaseInfoHander ft_keyWindow];
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


