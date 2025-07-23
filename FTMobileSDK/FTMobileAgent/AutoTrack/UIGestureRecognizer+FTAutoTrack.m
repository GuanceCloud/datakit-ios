//
//  UIGestureRecognizer+FTAutoTrack.m
//  FTMobileAgent
//
//  Created by hulilei on 2021/7/21.
//  Copyright © 2021 hll. All rights reserved.
//

#import "UIGestureRecognizer+FTAutoTrack.h"
#import "FTLog+Private.h"
#import "UIView+FTAutoTrack.h"
#import "FTAutoTrackHandler.h"
#import "FTConstants.h"
@implementation UIGestureRecognizer (FTAutoTrack)

- (void)ftTrackGestureRecognizerAppClick:(UIGestureRecognizer *)gesture{
    @try {
        // The gesture is in the Ended state
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
            if([FTAutoTrackHandler sharedInstance].addRumDatasDelegate && [[FTAutoTrackHandler sharedInstance].addRumDatasDelegate respondsToSelector:@selector(startAction:actionType:property:)]){
                [[FTAutoTrackHandler sharedInstance].addRumDatasDelegate startAction:view.ft_actionName actionType:FT_KEY_ACTION_TYPE_CLICK property:nil];
            }
        }
        
    }@catch (NSException *exception) {
        FTInnerLogError(@"%@ error: %@", self, exception);
    }
}
// Find the view where the gesture selection is located
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
