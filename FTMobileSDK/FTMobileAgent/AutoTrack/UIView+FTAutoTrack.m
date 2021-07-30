//
//  UIView+FTAutoTrack.m
//  FTAutoTrack
//
//  Created by 胡蕾蕾 on 2019/11/29.
//  Copyright © 2019 hll. All rights reserved.
//
#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif
#import "UIView+FTAutoTrack.h"
#import "FTBaseInfoHander.h"

@implementation UIView (FTAutoTrack)
-(UIViewController *)ft_currentViewController{
    __block UIResponder *next = nil;
    [FTBaseInfoHander performBlockDispatchMainSyncSafe:^{
        next = [self nextResponder];
        do {
            if ([next isKindOfClass:[UIViewController class]]) {
                break;        }
            next = [next nextResponder];
        } while (next != nil);
    }];
    if (next != nil) {
        return (UIViewController *)next;
    }
    return nil;
}
-(NSString *)ft_parentsView{
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
    //让视图树唯一
    UIViewController *vc = [self ft_currentViewController];
    if ([vc isKindOfClass:UINavigationController.class]) {
        UINavigationController *nav =(UINavigationController *)vc;
        vc = [nav.viewControllers lastObject];
    }
    vc?[str insertString:[NSString stringWithFormat:@"%@/",NSStringFromClass(vc.class)] atIndex:0]:nil;
    return str;
}
- (BOOL)isAlertView {
    UIResponder *responder = self;
    do {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        BOOL isUIAlertView = [responder isKindOfClass:UIAlertView.class];
        BOOL isUIActionSheet = [responder isKindOfClass:UIActionSheet.class];
#pragma clang diagnostic pop

        BOOL isUIAlertController = [responder isKindOfClass:UIAlertController.class];

    
        if (isUIAlertController || isUIAlertView || isUIActionSheet) {
            return YES;
        }
    } while ((responder = [responder nextResponder]));
    return NO;
}
/// 是否为弹框点击
- (BOOL)isAlertClick {
    if ([NSStringFromClass(self.class) isEqualToString:@"_UIInterfaceActionCustomViewRepresentationView"] || [NSStringFromClass(self.class) isEqualToString:@"_UIAlertControllerCollectionViewCell"]) { // 标记弹框
        return YES;
    }
    return NO;
}
- (UIViewController*)datafluxHelper_viewController {
    UIResponder *curNode = self.nextResponder;
    while (curNode) {
        if ([curNode isKindOfClass:[UIViewController class]]) {
            return (id)curNode;
        }
        curNode = [curNode nextResponder];
    }
    return nil;
}

@end
