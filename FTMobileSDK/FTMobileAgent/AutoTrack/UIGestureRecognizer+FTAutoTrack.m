//
//  UIGestureRecognizer+FTAutoTrack.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/7/21.
//  Copyright © 2021 hll. All rights reserved.
//

#import "UIGestureRecognizer+FTAutoTrack.h"
#import "FTLog.h"
#import "FTMonitorManager.h"
@implementation UIGestureRecognizer (FTAutoTrack)

- (void)ftTrackGestureRecognizerAppClick:(UIGestureRecognizer *)gesture{
    @try {
        // 手势处于 Ended 状态
        if (gesture.state != UIGestureRecognizerStateEnded) {
            return;
        }
        UIView *view = gesture.view;
        
        BOOL isTrackClass = [view isKindOfClass:UILabel.class] || [view isKindOfClass:UIImageView.class] ;
        
        
    }@catch (NSException *exception) {
        ZYErrorLog(@"%@ error: %@", self, exception);
    }
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
