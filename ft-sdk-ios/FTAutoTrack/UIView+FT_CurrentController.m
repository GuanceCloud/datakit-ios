//
//  UIView+FT_CurrentController.m
//  FTAutoTrack
//
//  Created by 胡蕾蕾 on 2019/11/29.
//  Copyright © 2019 hll. All rights reserved.
//

#import "UIView+FT_CurrentController.h"


@implementation UIView (FT_CurrentController)
-(UIViewController *)ft_getCurrentViewController{
    UIResponder *next = [self nextResponder];
    do {
        if ([next isKindOfClass:[UIViewController class]]) {
            return (UIViewController *)next;
        }
        next = [next nextResponder];
    } while (next != nil);
    return nil;
}
-(NSString *)ft_getParentsView{
    NSMutableString *str = [NSMutableString new];
    [str appendString:NSStringFromClass([self class])];
    UIView *currentView = self;
    UIView *parentView = [currentView superview];
    __block NSInteger index = 0;
    [parentView.subviews enumerateObjectsUsingBlock:^(__kindof UIView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if([obj isEqual:currentView]){
        index = idx;
        *stop = YES;
        }
    }];
    [str appendFormat:@"[%ld]",(long)index];

    while (![currentView isKindOfClass:[UIWindow class]]) {
        currentView = [currentView superview];
        if (!currentView) {
            break;
        }
        [str insertString:[NSString stringWithFormat:@"%@/",NSStringFromClass([currentView class])] atIndex:0];
    }
    return str;
}

@end
