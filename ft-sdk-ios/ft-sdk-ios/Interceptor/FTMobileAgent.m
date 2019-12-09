//
//  ZYInterceptor.m
//  RuntimDemo
//
//  Created by 胡蕾蕾 on 2019/11/28.
//  Copyright © 2019 hll. All rights reserved.
//

#import "FTMobileAgent.h"
#import "ZYAspects.h"
#import <UIKit/UIKit.h>
#import "ZYViewController_log.h"
#import "ZYLog.h"
#import "ZYTrackerEventDBTool.h"
#import <SystemConfiguration/SystemConfiguration.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import "ZYUploadTool.h"
#import "RecordModel.h"
#import "ZYBaseInfoHander.h"
@interface FTMobileAgent ()
@property (nonatomic) BOOL isForeground;
@property (nonatomic, assign) SCNetworkReachabilityRef reachability;
@property (nonatomic, strong) CTTelephonyNetworkInfo *telephonyInfo;
@property (nonatomic, strong) dispatch_queue_t serialQueue;
@property (nonatomic, strong) NSString *net;
@property (nonatomic, strong) NSString *radio;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) ZYUploadTool *upTool;

@end
@implementation FTMobileAgent{
    ZYViewController_log *_viewControllerLog;
}
static void ZYReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info) {
    if (info != NULL && [(__bridge NSObject*)info isKindOfClass:[FTMobileAgent class]]) {
        @autoreleasepool {
            FTMobileAgent *zy = (__bridge FTMobileAgent *)info;
            [zy reachabilityChanged:flags];
        }
    }
}
+ (void)setup{
   [FTMobileAgent sharedInstance];
}
+(void)registerAkId:(NSString *)aKId akSecret:(NSString *)akSecret{
    [FTMobileAgent sharedInstance];

}
// 单例
+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    static FTMobileAgent *sharedInstance;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[FTMobileAgent alloc] init];
    });
    return sharedInstance;
}
- (instancetype)init {
    if ([super init]) {
        //基础类型的记录
        NSString *label = [NSString stringWithFormat:@"io.zy.%p", self];

        self.serialQueue = dispatch_queue_create([label UTF8String], DISPATCH_QUEUE_SERIAL);
        [[ZYTrackerEventDBTool sharedManger] createTable];
        [self setupAppNetworkListeners];
        _viewControllerLog = [[ZYViewController_log alloc]init];
         __weak typeof(self) weakSelf = self;
        _viewControllerLog.block = ^(void){
            [weakSelf flush];
        };
    }
    return self;
}
#pragma mark ========== 网络与App的生命周期 ==========
- (void)setupAppNetworkListeners{
   BOOL reachabilityOk = NO;
   if ((_reachability = SCNetworkReachabilityCreateWithName(NULL, "www.baidu.com")) != NULL) {
       SCNetworkReachabilityContext context = {0, (__bridge void*)self, NULL, NULL, NULL};
       if (SCNetworkReachabilitySetCallback(_reachability, ZYReachabilityCallback, &context)) {
           if (SCNetworkReachabilitySetDispatchQueue(_reachability, self.serialQueue)) {
               reachabilityOk = YES;
           } else {
               SCNetworkReachabilitySetCallback(_reachability, NULL, NULL);
           }
       }
   }
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
    [notificationCenter addObserver:self
                           selector:@selector(appDidFinishLaunchingWithOptions:)
                                  name:UIApplicationDidFinishLaunchingNotification
                                object:nil];
    
}
- (void)reachabilityChanged:(SCNetworkReachabilityFlags)flags {
    if (flags & kSCNetworkReachabilityFlagsReachable) {
        if (flags & kSCNetworkReachabilityFlagsIsWWAN) {
            self.net = @"0";//2G/3G/4G
        } else {
            self.net = @"4";//WIFI
        }
    } else {
        self.net = @"-1";//未知
    }
    ZYDebug(@"联网状态: %@", [@"-1" isEqualToString:self.net]?@"未知":[@"0" isEqualToString:self.net]?@"移动网络":@"WIFI");
}

- (void)applicationWillTerminate:(NSNotification *)notification {
         ZYDebug(@"applicationWillTerminate ");

}
- (void)appDidFinishLaunchingWithOptions:(NSNotification *)notification{
            RecordModel *model = [RecordModel new];
            NSDictionary *data =@{
                                @"op":@"lanc",
                              };
            model.data =[ZYBaseInfoHander convertToJsonData:data];
            [[ZYTrackerEventDBTool sharedManger] insertItemWithItemData:model];
            ZYDebug(@"data == %@",data);
}
- (void)applicationWillResignActive:(NSNotification *)notification {
     @try {
        self.isForeground = NO;
         [self stopFlushTimer];
     }
     @catch (NSException *exception) {
         ZYDebug(@"applicationWillResignActive exception %@",exception);
     }

}
- (void)applicationDidBecomeActive:(NSNotification *)notification {
      @try {
        self.isForeground = YES;
          [self flush];
      }
      @catch (NSException *exception) {
        ZYDebug(@"applicationDidBecomeActive exception %@",exception);
      }
}
- (void)applicationDidEnterBackground:(NSNotification *)notification {
         ZYDebug(@"applicationDidEnterBackground ");

}
#pragma mark - 上报策略

// 启动事件发送定时器
- (void)startFlushTimer {
    [self stopFlushTimer];
    dispatch_async(dispatch_get_main_queue(), ^{
            self.timer = [NSTimer scheduledTimerWithTimeInterval:2.0
                                                          target:self
                                                        selector:@selector(flush)
                                                        userInfo:nil
                                                         repeats:YES];
            
            ZYDebug(@"启动事件发送定时器");
    });
}

// 关闭事件发送定时器
- (void)stopFlushTimer {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.timer) {
            [self.timer invalidate];
            ZYDebug(@"关闭事件发送定时器");
        }
        self.timer = nil;
    });
}
- (void)flush{
    dispatch_async(self.serialQueue, ^{
        if (![self.net isEqualToString:@"-1"]) {
          [self.upTool upload];
        }
       });
}
-(ZYUploadTool *)upTool{
    if (!_upTool) {
        _upTool = [ZYUploadTool new];
    }
    return _upTool;
}
@end
