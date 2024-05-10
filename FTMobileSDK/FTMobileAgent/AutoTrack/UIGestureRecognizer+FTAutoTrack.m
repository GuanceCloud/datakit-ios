//
//  UIGestureRecognizer+FTAutoTrack.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/7/21.
//  Copyright © 2021 hll. All rights reserved.
//

#import "UIGestureRecognizer+FTAutoTrack.h"
#import "FTLog+Private.h"
#import "UIView+FTAutoTrack.h"
#import "FTTrack.h"
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
            if([FTTrack sharedInstance].addRumDatasDelegate && [[FTTrack sharedInstance].addRumDatasDelegate respondsToSelector:@selector(addClickActionWithName:)]){
                [[FTTrack sharedInstance].addRumDatasDelegate addClickActionWithName:view.ft_actionName];
            }
        }
        
    }@catch (NSException *exception) {
        FTInnerLogError(@"%@ error: %@", self, exception);
    }
}
// 查找弹框手势选择所在的 view
- (UIView *)searchGestureTouchView:(UIGestureRecognizer *)gesture {
    UIView *gestureView = gesture.view;
    CGPoint point = [gesture locationInView:gestureView];

    UIView *view = [gestureView.subviews lastObject];
    UIView *sequenceView = [view.subviews lastObject];
    UIView *separableSequenceView = [sequenceView.subviews firstObject];
    UIView *stackView = [separableSequenceView.subviews firstObject];
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
-(instancetype)ft_initWithTarget:(id)target action:(SEL)action{
    [self ft_initWithTarget:target action:action];
    [self removeTarget:target action:action];
    [self addTarget:target action:action];
    return self;
}
- (void)ft_addTarget:(id)target action:(SEL)action {
    [self ft_addTarget:self action:@selector(ftTrackGestureRecognizerAppClick:)];
    [self ft_addTarget:target action:action];
}
@end

@implementation UILongPressGestureRecognizer (FTAutoTrack)
-(instancetype)ft_initWithTarget:(id)target action:(SEL)action{
    [self ft_initWithTarget:target action:action];
    [self removeTarget:target action:action];
    [self addTarget:target action:action];
    return self;
}
- (void)ft_addTarget:(id)target action:(SEL)action {
    [self ft_addTarget:self action:@selector(ftTrackGestureRecognizerAppClick:)];
    [self ft_addTarget:target action:action];
}
@end
