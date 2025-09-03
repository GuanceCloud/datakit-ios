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

// Handle TVOS click events
- (void)ftSendEvent:(UIEvent *)event;
#endif
@end

NS_ASSUME_NONNULL_END
