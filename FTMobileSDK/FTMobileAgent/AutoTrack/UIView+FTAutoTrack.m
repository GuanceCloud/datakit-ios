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

@implementation UIView (FTAutoTrack)
-(NSString *)actionName{
    return nil;
}
-(NSString *)ft_actionName{
    NSString *actionName = self.actionName?:[NSString stringWithFormat:@"[%@]",NSStringFromClass(self.class)];

    if (self.accessibilityIdentifier) {
        actionName = [actionName stringByAppendingFormat:@"(%@)",self.accessibilityIdentifier];
    }
    return actionName;
}
- (BOOL)isAlertView {
#if TARGET_OS_IOS
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
#endif
    return NO;
}
/// 是否为弹框点击
- (BOOL)isAlertClick {
    if ([NSStringFromClass(self.class) isEqualToString:@"_UIInterfaceActionCustomViewRepresentationView"] || [NSStringFromClass(self.class) isEqualToString:@"_UIAlertControllerCollectionViewCell"]) { // 标记弹框
        return YES;
    }
    return NO;
}
@end
@implementation UIButton (FTAutoTrack)
-(NSString *)actionName{
    if(self.currentTitle.length>0 || self.titleLabel.text.length>0){
        NSString *title = self.currentTitle.length>0?self.currentTitle:self.titleLabel.text;
        return [NSString stringWithFormat:@"[%@][%@]",NSStringFromClass(self.class),title];
    }
    return nil;
}

@end
@implementation UILabel (FTAutoTrack)
-(NSString *)actionName{
    if(self.text.length){
        return [NSString stringWithFormat:@"[%@][%@]",NSStringFromClass(self.class),self.text];
    }
    return nil;
}
@end

@implementation UISegmentedControl (FTAutoTrack)

-(NSString *)actionName{
    NSString *title = [self titleForSegmentAtIndex:self.selected];
    return title?[NSString stringWithFormat:@"[%@]%@",NSStringFromClass(self.class),title]:nil;
}
@end

@implementation UIStepper (FTAutoTrack)
-(NSString *)actionName{
    return [NSString stringWithFormat:@"[%@]%.2f",NSStringFromClass(self.class),self.value];
}
@end
@implementation UISlider (FTAutoTrack)

-(NSString *)actionName{
    return [NSString stringWithFormat:@"[%@]%.2f",NSStringFromClass(self.class),self.value];
}

@end
@implementation UIPageControl (FTAutoTrack)

-(NSString *)actionName{
    return [NSString stringWithFormat:@"[%@]%ld",NSStringFromClass(self.class),(long)self.currentPage];
}
@end
@implementation UISwitch (FTAutoTrack)

-(NSString *)actionName{
    NSString *title = self.isOn?@"On":@"Off";
    return [NSString stringWithFormat:@"[%@]%@",NSStringFromClass(self.class),title];
}
@end
@implementation UITableViewCell (FTAutoTrack)

-(NSString *)actionName{
    if(self.textLabel.text){
        return [NSString stringWithFormat:@"[%@]%@",NSStringFromClass(self.class),self.textLabel.text];
    }
    return nil;
}
@end

@implementation UICollectionViewListCell (FTAutoTrack)
-(NSString *)actionName{
    if(self.defaultContentConfiguration.text){
        return [NSString stringWithFormat:@"[%@]%@",NSStringFromClass(self.class),self.defaultContentConfiguration.text];
    }
    return nil;
}
@end
