//
//  ZYInterceptor.m
//  RuntimDemo
//
//  Created by 胡蕾蕾 on 2019/11/28.
//  Copyright © 2019 hll. All rights reserved.
//

#import "ZYInterceptor.h"
#import "ZYAspects.h"
#import <UIKit/UIKit.h>
#import "ZYViewController_log.h"
#import "ZYLog.h"
#import "ZYTrackerEventDBTool.h"
@interface ZYInterceptor ()
@property (nonatomic) BOOL isForeground;

@end
@implementation ZYInterceptor{
    ZYViewController_log *_viewControllerLog;
}

+ (void)setup{
   [ZYInterceptor sharedInstance];
}
// 单例
+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    static ZYInterceptor *sharedInstance;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[ZYInterceptor alloc] init];
    });
    return sharedInstance;
}
- (instancetype)init {
    if ([super init]) {
        //基础类型的记录
        [[ZYTrackerEventDBTool sharedManger] createTable];
        [self setupAppNetworkListeners];
        _viewControllerLog = [[ZYViewController_log alloc]init];
         
    }
    return self;
}
#pragma mark ========== 网络与App的生命周期 ==========
- (void)setupAppNetworkListeners{
   
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    
    // 应用生命周期通知
    [notificationCenter addObserver:self
                           selector:@selector(applicationWillTerminate:)
                               name:UIApplicationWillTerminateNotification
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(applicationWillResignActive:)
                               name:UIApplicationWillResignActiveNotification
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(applicationDidBecomeActive:)
                               name:UIApplicationDidBecomeActiveNotification
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(applicationDidEnterBackground:)
                               name:UIApplicationDidEnterBackgroundNotification
                             object:nil];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
         ZYDebug(@"applicationWillTerminate ");

}
- (void)applicationWillResignActive:(NSNotification *)notification {
     @try {
        self.isForeground = NO;
        
     }
     @catch (NSException *exception) {
         ZYDebug(@"applicationWillResignActive exception %@",exception);
     }

}
- (void)applicationDidBecomeActive:(NSNotification *)notification {
      @try {
        self.isForeground = YES;
        
      }
      @catch (NSException *exception) {
        ZYDebug(@"applicationDidBecomeActive exception %@",exception);
      }
}
- (void)applicationDidEnterBackground:(NSNotification *)notification {
         ZYDebug(@"applicationDidEnterBackground ");

}


@end
