//
//  UIGestureRecognizer+FTAutoTrack.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/7/21.
//  Copyright © 2021 hll. All rights reserved.
//

#import "UIGestureRecognizer+FTAutoTrack.h"
#import "FTLog.h"
#import "UIView+FTAutoTrack.h"
#import "FTMonitorManager.h"
#import "FTRUMManager.h"
@implementation UIGestureRecognizer (FTAutoTrack)

- (void)ftTrackGestureRecognizerAppClick:(UIGestureRecognizer *)gesture{
    @try {
        // 手势处于 Ended 状态
        if (gesture.state != UIGestureRecognizerStateEnded) {
            return;
        }
        UIView *view = gesture.view;
        if(view.isAlertView){
            UIView *touchView = [self searchGestureTouchView:gesture];
            if (touchView) {
                view = touchView;
            }
        }
        BOOL isAlterType = [view isAlertClick];
        BOOL isTrackClass = [view isKindOfClass:UILabel.class] || [view isKindOfClass:UIImageView.class] ||isAlterType;
        if(isTrackClass){
            [[FTMonitorManager sharedInstance].rumManger addAction:view];
        }
        
    }@catch (NSException *exception) {
        ZYErrorLog(@"%@ error: %@", self, exception);
    }
}
// 查找弹框手势选择所在的 view
- (UIView *)searchGestureTouchView:(UIGestureRecognizer *)gesture {
    UIView *gestureView = gesture.view;
    CGPoint point = [gesture locationInView:gestureView];

    UIView *view = [gestureView.subviews lastObject];
    UIView *sequeceView = [view.subviews lastObject];
    UIView *reparatableVequeceView = [sequeceView.subviews firstObject];
    UIView *stackView = [reparatableVequeceView.subviews firstObject];
    if ([NSStringFromClass(gestureView.class) isEqualToString:@"_UIAlertControllerView"]) {
        // iOS9 上，为 UICollectionView
        stackView = [reparatableVequeceView.subviews lastObject];
    }
    for (UIView *subView in stackView.subviews) {
        CGRect rect = [subView convertRect:subView.bounds toView:gestureView];
        if (CGRectContainsPoint(rect, point)) {
            return subView;
        }
    }
    return nil;
}

@end


@implementation UITapGestureRecognizer (FTAutoTrack)
-(instancetype)dataflux_initWithTarget:(id)target action:(SEL)action{
    [self dataflux_initWithTarget:target action:action];
    [self removeTarget:target action:action];
    [self addTarget:target action:action];
    return self;
}
- (void)dataflux_addTarget:(id)target action:(SEL)action {
    [self dataflux_addTarget:self action:@selector(ftTrackGestureRecognizerAppClick:)];
    [self dataflux_addTarget:target action:action];
}
@end

@implementation UILongPressGestureRecognizer (FTAutoTrack)
-(instancetype)dataflux_initWithTarget:(id)target action:(SEL)action{
    [self dataflux_initWithTarget:target action:action];
    [self removeTarget:target action:action];
    [self addTarget:target action:action];
    return self;
}
- (void)dataflux_addTarget:(id)target action:(SEL)action {
    [self dataflux_addTarget:self action:@selector(ftTrackGestureRecognizerAppClick:)];
    [self dataflux_addTarget:target action:action];
}
@end
