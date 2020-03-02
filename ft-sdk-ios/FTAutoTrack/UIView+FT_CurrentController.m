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
    [str appendString:@"[0]"];
    UIView *currentView = self;
    NSInteger index = 0;
    
    while (![currentView isKindOfClass:[UIWindow class]]) {
        index++;
        currentView = [currentView superview];
        if (!currentView) {
            break;
        }
        [str insertString:[NSString stringWithFormat:@"%@[%ld]/",NSStringFromClass([currentView class]),(long)index] atIndex:0];
    }
    return str;
}

@end
