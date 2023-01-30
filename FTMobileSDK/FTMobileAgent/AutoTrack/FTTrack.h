//
//  FTTrack.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/11/27.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "FTRumDatasProtocol.h"
NS_ASSUME_NONNULL_BEGIN
/// View、Action 采集类
@interface FTTrack : NSObject
///
@property (nonatomic,weak) id<FTRumDatasProtocol> addRumDatasDelegate;
/// 当前的显示的控制器页面 仅在主线程使用 所以无多线程调用问题
@property (nonatomic, weak) UIViewController *currentController;
/// 单例
+ (instancetype)sharedInstance;

/// 开启采集
/// - Parameters:
///   - enable: 是否采集 View 数据
///   - enable: 是否采集 Action 数据
-(void)startWithTrackView:(BOOL)enable action:(BOOL)enable;
@end

NS_ASSUME_NONNULL_END
