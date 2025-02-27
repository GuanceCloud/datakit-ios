//
//  UIApplication+Test.h
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2025/2/7.
//  Copyright © 2025 GuanceCloud. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UIApplication+FTAutoTrack.h"

NS_ASSUME_NONNULL_BEGIN

@interface UIApplication ()
#if TARGET_OS_TV

// 处理 TVOS 点击事件
- (void)ftSendEvent:(UIEvent *)event;
#endif
@end

NS_ASSUME_NONNULL_END
