//
//  FTSessionReplayTouches.h
//  FTMobileAgent
//
//  Created by hulilei on 2022/12/23.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "FTViewAttributes.h"
NS_ASSUME_NONNULL_BEGIN
@class FTTouchSnapshot,FTWindowObserver;
@interface FTSessionReplayTouches : NSObject
-(instancetype)initWithWindowObserver:(FTWindowObserver *)observer;
/// 获取点击的点集合 （主线程操作）
-(FTTouchSnapshot *)takeTouchSnapshotWithContext:(FTSRContext *)context;

@end

NS_ASSUME_NONNULL_END
