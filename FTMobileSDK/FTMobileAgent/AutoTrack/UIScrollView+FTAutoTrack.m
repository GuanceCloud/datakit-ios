//
//  UIScrollView+FTAutoTrack.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/7/28.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import "UIScrollView+FTAutoTrack.h"
#import "FTSwizzler.h"
#import "FTMonitorManager.h"
@implementation UITableView (FTAutoTrack)

- (void)dataflux_setDelegate:(id <UITableViewDelegate>)delegate {
    [self dataflux_setDelegate:delegate];
    if (self.delegate == nil) {
        return;
    }
    SEL selector = @selector(tableView:didSelectRowAtIndexPath:);
    Class class = [FTSwizzler realDelegateClassFromSelector:selector proxy:delegate];
    
    if ([FTSwizzler realDelegateClass:class respondsToSelector:selector]) {
        [FTSwizzler swizzleInstanceMethod:selector inClass:class newImpFactory:^id(FTSwizzleInfo *swizzleInfo) {
            void (*originalImplementation_)(__unsafe_unretained id,SEL,id,id);
            SEL selector_ = swizzleInfo.selector;
            return ^void(__unsafe_unretained id instance,id tableView,id indexPath){
                [[FTMonitorManager sharedInstance] trackClickWithView:tableView];
                ((__typeof(originalImplementation_))[swizzleInfo getOriginalImplementation])(instance, selector_,tableView,indexPath);
            };
        }];
    }
    
}

@end


@implementation UICollectionView (FTAutoTrack)

- (void)dataflux_setDelegate:(id <UICollectionViewDelegate>)delegate {
    [self dataflux_setDelegate:delegate];
    
    if (self.delegate == nil) {
        return;
    }
    SEL selector = @selector(collectionView:didSelectItemAtIndexPath:);
    Class class = [FTSwizzler realDelegateClassFromSelector:selector proxy:delegate];
    
    if ([FTSwizzler realDelegateClass:class respondsToSelector:selector]) {
        [FTSwizzler swizzleInstanceMethod:selector inClass:class newImpFactory:^id(FTSwizzleInfo *swizzleInfo) {
            void (*originalImplementation_)(__unsafe_unretained id,SEL,id,id);
            SEL selector_ = swizzleInfo.selector;
            return ^void(__unsafe_unretained id instance,id collectionView,id indexPath){
                [[FTMonitorManager sharedInstance] trackClickWithView:collectionView];
                ((__typeof(originalImplementation_))[swizzleInfo getOriginalImplementation])(instance, selector_,collectionView,indexPath);
            };
        }];
    }
    
}
@end

