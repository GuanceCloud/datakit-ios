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
#import "FTRUMManager.h"
@implementation UITableView (FTAutoTrack)

- (void)dataflux_setDelegate:(id <UITableViewDelegate>)delegate {
    [self dataflux_setDelegate:delegate];
    if (self.delegate == nil) {
        return;
    }
    SEL selector = @selector(tableView:didSelectRowAtIndexPath:);
    Class class = [FTSwizzler realDelegateClassFromSelector:selector proxy:delegate];
    
    if ([FTSwizzler realDelegateClass:class respondsToSelector:selector]) {
        void (^didSelectRowBlock)(id, SEL, id, id) = ^(id view, SEL command, UITableView *tableView, NSIndexPath *indexPath) {
            
            if (tableView && indexPath) {
                UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
                [[FTMonitorManager sharedInstance].rumManger addAction:cell];
            }
        };
        
        [FTSwizzler swizzleSelector:selector
                            onClass:class
                          withBlock:didSelectRowBlock
                              named:@"tableView_didSelect"];
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
        void (^didSelectItemBlock)(id, SEL, id, id) = ^(id view, SEL command, UICollectionView *collectionView, NSIndexPath *indexPath) {
            
            if (collectionView && indexPath) {
                UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
                [[FTMonitorManager sharedInstance].rumManger addAction:cell];
            }
        };
        
        [FTSwizzler swizzleSelector:selector
                            onClass:class
                          withBlock:didSelectItemBlock
                              named:@"collectionView_didSelect"];
    }
    
}
@end

