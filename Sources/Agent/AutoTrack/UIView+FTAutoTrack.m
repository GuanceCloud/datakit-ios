//
//  UIView+FTAutoTrack.m
//  FTAutoTrack
//
//  Created by hulilei on 2019/11/29.
//  Copyright 2021 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif
#import <TargetConditionals.h>
#if TARGET_OS_IOS || TARGET_OS_TV
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
        BOOL isUIAlertController = [responder isKindOfClass:UIAlertController.class];
        if (isUIAlertController) {
            return YES;
        }
    } while ((responder = [responder nextResponder]));
#endif
    return NO;
}
/// Whether it is a pop-up click
- (BOOL)isAlertClick {
    if ([NSStringFromClass(self.class) isEqualToString:@"_UIInterfaceActionCustomViewRepresentationView"] 
    || [NSStringFromClass(self.class) isEqualToString:@"_UIAlertControllerCollectionViewCell"]) { // mark popup
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

#endif
