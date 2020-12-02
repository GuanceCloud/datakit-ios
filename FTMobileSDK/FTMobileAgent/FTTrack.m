//
//  FTTrack.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/11/27.
//  Copyright © 2020 hll. All rights reserved.
//

#import "FTTrack.h"
#import "FTConstants.h"
#import <UIKit/UIKit.h>
#import "ZYAspects.h"
#import "UIViewController+FT_RootVC.h"
#import "FTLog.h"
#import "BlacklistedVCClassNames.h"
#import "FTMobileAgent+Private.h"
#import "NSString+FTAdd.h"
#import "NSDate+FTAdd.h"
#define WeakSelf __weak typeof(self) weakSelf = self;
@interface FTTrack()
@property (nonatomic,assign) BOOL isLaunched;
@property (nonatomic,assign) CFTimeInterval launch;
@property (nonatomic, strong) NSMutableArray *aspectTokenAry;
@end
@implementation FTTrack
-(instancetype)init{
    self = [super init];
    if (self) {
        _isLaunched = NO;
        [self startTrack];
    }
    return  self;
}
- (void)startTrack{
  id<ZY_AspectToken> viewLoad = [UIViewController aspect_hookSelector:@selector(viewDidLoad) withOptions:ZY_AspectPositionBefore usingBlock:^(id<ZY_AspectInfo> info){
       UIViewController * vc = [info instance];
       vc.viewLoadStartTime =CFAbsoluteTimeGetCurrent();
   } error:nil];
   WeakSelf
   id<ZY_AspectToken> viewAppear = [UIViewController aspect_hookSelector:@selector(viewDidAppear:) withOptions:ZY_AspectPositionAfter usingBlock:^(id<ZY_AspectInfo> info){
       UIViewController * vc = [info instance];
       if(![weakSelf isBlackListContainsViewController:vc]&&vc.viewLoadStartTime){
           CFTimeInterval time = CFAbsoluteTimeGetCurrent();
           float loadTime = (time - vc.viewLoadStartTime);
           vc.viewLoadStartTime = 0;
           [weakSelf trackOpenWithCpn:vc duration:loadTime];
           if (!weakSelf.isLaunched) {
               [weakSelf trackStartWithTime:CFAbsoluteTimeGetCurrent()];
               weakSelf.isLaunched = YES;
           }
       }
   } error:nil];
    [self.aspectTokenAry addObjectsFromArray:@[viewLoad,viewAppear]];
}
- (BOOL)isBlackListContainsViewController:(UIViewController *)viewController {
    static NSSet * blacklistedClasses  = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        @try {
            NSArray *blacklistedViewControllerClassNames =[BlacklistedVCClassNames ft_blacklistedViewControllerClassNames];
            blacklistedClasses = [NSSet setWithArray:blacklistedViewControllerClassNames];
            
        } @catch(NSException *exception) {  // json加载和解析可能失败
            ZYDebug(@"error: %@",exception);
        }
    });
    
    __block BOOL isContains = NO;
    [blacklistedClasses enumerateObjectsUsingBlock:^(id  _Nonnull obj, BOOL * _Nonnull stop) {
        NSString *blackClassName = (NSString *)obj;
        Class blackClass = NSClassFromString(blackClassName);
        if (blackClass && [viewController isKindOfClass:blackClass]) {
            isContains = YES;
            *stop = YES;
        }
    }];
    return isContains;
}
-(void)trackStartWithTime:(CFTimeInterval)time{
    @try {
        [[FTMobileAgent sharedInstance] trackStartWithViewLoadTime:time];
    } @catch (NSException *exception) {
        ZYErrorLog(@" error: %@", exception);
    }
}
-(void)trackOpenWithCpn:(id)cpn duration:(float)duration{
    @try {
        FTMobileAgent *instance = [FTMobileAgent sharedInstance];
        if ([instance judgeIsTraceSampling]) {
            NSString *name = NSStringFromClass([cpn class]);
            NSString *view_id = [name ft_md5HashToUpper32Bit];
            NSString *path = [(UIViewController *)cpn ft_getVCPath];
            NSDictionary *tags = @{@"view_id":view_id,
                                   @"view_name":name,
                                   @"view_path":path,
            };
            NSDictionary *fields = @{
                @"view_load":[NSNumber numberWithInt:duration*1000*1000],
            };
            [instance track:FT_RUM_APP_VIEW tags:tags fields:fields tm:[[NSDate date] ft_dateTimestamp]];
            [instance trackES:@"view" terminal:@"app" tags:tags fields:fields];
        }
    } @catch (NSException *exception) {
        ZYErrorLog(@" error: %@", exception);
    }
}
-(void)dealloc{
    [self.aspectTokenAry enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        id<ZY_AspectToken> token = obj;
        [token remove];
    }];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
@end
