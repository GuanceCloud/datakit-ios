//
//  FTSessionManger.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/5/21.
//  Copyright © 2021 hll. All rights reserved.
//
#import "FTSessionManger.h"
#import "FTBaseInfoHander.h"
#import "FTRUMSessionScope.h"
#import "FTRUMScope.h"
typedef NS_ENUM(NSInteger,ErrorType) {
    ErrorNet,
};


@interface FTSessionManger()<FTRUMSessionViewDelegate,FTRUMSessionErrorDelegate,FTRUMSessionActionDelegate,FTRUMSessionSourceDelegate>
@property (nonatomic, strong) FTRUMSessionScope *currentSession;
@property (nonatomic, weak) UIViewController *currentController;

@end
@implementation FTSessionManger

#pragma mark - FTRUMSessionViewDelegate -

#pragma mark - FTRUMSessionErrorDelegate -

#pragma mark - FTRUMSessionActionDelegate -
-(void)notify_viewDidAppear:(UIViewController *)viewController{
    FTRUMModel *model = [FTRUMModel new];
    [self.currentSession.assistant process:model];
}
-(void)notify_viewDidDisappear:(UIViewController *)viewController{
   
}
- (void)applicationDidBecomeActive:(BOOL)isHot{
    
}
- (void)applicationWillResignActive{
    
}

#pragma mark - FTRUMSessionSourceDelegate -



- (void)refresh:(FTRUMSessionScope *)expiredSession command:(NSDictionary *)command{
    
}
//private func refresh(expiredSession: RUMSessionScope, on command: RUMCommand) {
//    let refreshedSession = RUMSessionScope(from: expiredSession, startTime: command.time)
//    sessionScope = refreshedSession
//    _ = refreshedSession.process(command: command)


@end
