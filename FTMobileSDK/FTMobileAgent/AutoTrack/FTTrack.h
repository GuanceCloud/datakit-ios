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
@interface FTTrack : NSObject
@property (nonatomic,weak) id<FTRumDatasProtocol> addRumDatasDelegate;
// 仅在主线程使用 所以无多线程调用问题
@property (nonatomic, weak) UIViewController *currentController;
+ (instancetype)sharedInstance;

-(void)startWithTrackView:(BOOL)enable action:(BOOL)enable;
@end

NS_ASSUME_NONNULL_END
