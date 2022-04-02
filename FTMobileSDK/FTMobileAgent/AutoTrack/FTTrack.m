//
//  FTTrack.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/11/27.
//  Copyright © 2020 hll. All rights reserved.
//

#import "FTTrack.h"
#import "UIViewController+FTAutoTrack.h"
#import "FTLog.h"
#import "FTSwizzle.h"
#import "UIApplication+FTAutoTrack.h"
#import "UIViewController+FTAutoTrack.h"
#import "UIGestureRecognizer+FTAutoTrack.h"
#import "UIScrollView+FTAutoTrack.h"
#import "FTConfigManager.h"
@interface FTTrack()

@end
@implementation FTTrack
-(instancetype)init{
    self = [super init];
    if (self) {
        [self startHook];
    }
    return  self;
}
- (void)startHook{
    if (FTConfigManager.sharedInstance.rumConfig.enableTraceUserView) {
        [self logViewControllerLifeCycle];
    }
    if ([FTConfigManager sharedInstance].rumConfig.enableTraceUserAction) {
        [self logTargetAction];
    }
  
}
- (void)logViewControllerLifeCycle{
    @try {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            NSError *error = NULL;
            [UIViewController ft_swizzleMethod:@selector(viewDidLoad) withMethod:@selector(dataflux_viewDidLoad) error:&error];
            [UIViewController ft_swizzleMethod:@selector(viewDidAppear:) withMethod:@selector(dataflux_viewDidAppear:) error:&error];
            [UIViewController ft_swizzleMethod:@selector(viewDidDisappear:) withMethod:@selector(dataflux_viewDidDisappear:) error:&error];
        });
    } @catch (NSException *exception) {
        ZYErrorLog(@"exception: %@", self, exception);
    }
    
}
- (void)logTargetAction{
    @try {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            NSError *error = NULL;
            [UITableView ft_swizzleMethod:@selector(setDelegate:) withMethod:@selector(dataflux_setDelegate:) error:&error];
            [UICollectionView ft_swizzleMethod:@selector(setDelegate:) withMethod:@selector(dataflux_setDelegate:) error:&error];
            [UIApplication ft_swizzleMethod:@selector(sendAction:to:from:forEvent:) withMethod:@selector(dataflux_sendAction:to:from:forEvent:) error:&error];
            [UITapGestureRecognizer ft_swizzleMethod:@selector(initWithTarget:action:) withMethod:@selector(dataflux_initWithTarget:action:) error:&error];
            [UILongPressGestureRecognizer ft_swizzleMethod:@selector(initWithTarget:action:) withMethod:@selector(dataflux_initWithTarget:action:) error:&error];
            [UITapGestureRecognizer ft_swizzleMethod:@selector(addTarget:action:) withMethod:@selector(dataflux_addTarget:action:) error:&error];
            [UILongPressGestureRecognizer ft_swizzleMethod:@selector(addTarget:action:) withMethod:@selector(dataflux_addTarget:action:) error:&error];
        });
    } @catch (NSException *exception) {
        ZYErrorLog(@"exception: %@", self, exception);
    }
   
}

@end
