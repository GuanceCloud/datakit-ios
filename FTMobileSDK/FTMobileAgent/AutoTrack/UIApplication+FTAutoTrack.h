//
//  UIApplication+FTAutoTrack.h
//  FTMobileAgent
//
//  Created by hulilei on 2021/7/21.
//  Copyright © 2021 hll. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIApplication (FTAutoTrack)
#if TARGET_OS_IOS || TARGET_OS_TV
- (void)ft_sendEvent:(UIEvent *)event;
#endif
@end

NS_ASSUME_NONNULL_END
