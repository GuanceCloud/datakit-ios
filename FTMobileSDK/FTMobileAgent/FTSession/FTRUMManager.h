//
//  FTSessionManger.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/5/21.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTRUMHandler.h"
#import <UIKit/UIKit.h>
@class FTRumConfig;
NS_ASSUME_NONNULL_BEGIN

@interface FTRUMManager : FTRUMHandler
@property (nonatomic, strong) FTRumConfig *rumConfig;
-(instancetype)initWithRumConfig:(FTRumConfig *)rumConfig;

-(void)startView:(UIViewController *)viewController;
-(void)startView:(NSString *)viewID viewName:(NSString *)viewName viewReferrer:(NSString *)viewReferrer loadDuration:(NSNumber *)loadDuration;

-(void)stopView:(UIViewController *)viewController;
-(void)stopViewWithViewID:(NSString *)viewID;

- (void)addAction:(UIView *)clickView;
- (void)addActionWithActionName:(NSString *)actionName;

- (void)addLaunch:(BOOL)isHot duration:(NSNumber *)duration;
- (void)applicationWillTerminate;

- (void)resourceStart:(NSString *)identifier;
- (void)resourceCompleted:(NSString *)identifier tags:(NSDictionary *)tags fields:(NSDictionary *)fields time:(NSDate *)time;
- (void)resourceError:(NSString *)identifier tags:(NSDictionary *)tags fields:(NSDictionary *)fields time:(NSDate *)time;

- (void)addError:(NSDictionary *)tags field:(NSDictionary *)field;
- (void)addLongTask:(NSDictionary *)tags field:(NSDictionary *)field;

- (void)addWebviewData:(NSString *)measurement tags:(NSDictionary *)tags fields:(NSDictionary *)fields tm:(long long)tm;

-(NSDictionary *)getCurrentSessionInfo;
@end

NS_ASSUME_NONNULL_END
