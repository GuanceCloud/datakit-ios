//
//  FTGlobalRumManager.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/4/14.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "FTEnumConstant.h"
NS_ASSUME_NONNULL_BEGIN
@class  FTRUMManager,FTRumConfig;
// 用于 开启各项数据的采集 
@interface FTGlobalRumManager : NSObject
@property (nonatomic, strong) FTRUMManager *rumManger;
@property (nonatomic, weak) UIViewController *currentController;
@property (nonatomic, assign) AppState appState; //正在运行

/**
 * 获取 FTMonitorManager 单例
 * @return 返回的单例
*/
+ (instancetype)sharedInstance;

-(void)setRumConfig:(FTRumConfig *)rumConfig;

- (void)trackViewDidDisappear:(UIViewController *)viewController;
- (void)trackViewDidAppear:(UIViewController *)viewController;
- (void)resetInstance;
@end

NS_ASSUME_NONNULL_END
