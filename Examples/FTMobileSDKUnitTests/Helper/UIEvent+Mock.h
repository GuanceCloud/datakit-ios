//
//  UIEvent+Mock.h
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2025/2/7.
//  Copyright © 2025 GuanceCloud. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
@interface UIPressesMock:UIPress
-(instancetype)initWithPhase:(UIPressPhase)phase type:(UIPressType)type view: (UIView*)view;
@end
@interface UITouchMock:UITouch
-(instancetype)initWithPhase:(UITouchPhase)phase view:(nullable UIView*)view location:(CGPoint)location;
@end
@interface UIEvent (Mock)
+ (UIPressesEvent*)mockWithPress:(UIPress*)press;
+ (UIEvent*)mockWithTouch:(UITouch*)touch;
+ (UIEvent*)mockWithTouches:(nullable NSSet<UITouch*>*)touches;
@end

NS_ASSUME_NONNULL_END
