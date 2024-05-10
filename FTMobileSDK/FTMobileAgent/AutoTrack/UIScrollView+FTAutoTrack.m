//
//  UIScrollView+FTAutoTrack.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/7/28.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import "UIScrollView+FTAutoTrack.h"
#import "FTSwizzler.h"
#import "FTTrack.h"
#import "UIView+FTAutoTrack.h"
@implementation UITableView (FTAutoTrack)

- (void)ft_setDelegate:(id <UITableViewDelegate>)delegate {
    [self ft_setDelegate:delegate];
    if (self.delegate == nil) {
        return;
    }
    SEL selector = @selector(tableView:didSelectRowAtIndexPath:);
    Class class = [FTSwizzler realDelegateClassFromSelector:selector proxy:delegate];
    
    if ([FTSwizzler realDelegateClass:class respondsToSelector:selector]) {
        void (^didSelectRowBlock)(id, SEL, id, id) = ^(id view, SEL command, UITableView *tableView, NSIndexPath *indexPath) {
            
            if (tableView && indexPath) {
                UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
                if([FTTrack sharedInstance].addRumDatasDelegate && [[FTTrack sharedInstance].addRumDatasDelegate respondsToSelector:@selector(addClickActionWithName:)]){
                    [[FTTrack sharedInstance].addRumDatasDelegate addClickActionWithName:cell.ft_actionName];
                }
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

- (void)ft_setDelegate:(id <UICollectionViewDelegate>)delegate {
    [self ft_setDelegate:delegate];
    
    if (self.delegate == nil) {
        return;
    }
    SEL selector = @selector(collectionView:didSelectItemAtIndexPath:);
    Class class = [FTSwizzler realDelegateClassFromSelector:selector proxy:delegate];
    
    if ([FTSwizzler realDelegateClass:class respondsToSelector:selector]) {
        void (^didSelectItemBlock)(id, SEL, id, id) = ^(id view, SEL command, UICollectionView *collectionView, NSIndexPath *indexPath) {
            
            if (collectionView && indexPath) {
                UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
                if([FTTrack sharedInstance].addRumDatasDelegate && [[FTTrack sharedInstance].addRumDatasDelegate respondsToSelector:@selector(addClickActionWithName:)]){
                    [[FTTrack sharedInstance].addRumDatasDelegate addClickActionWithName:cell.ft_actionName];
                }
            }
        };
        
        [FTSwizzler swizzleSelector:selector
                            onClass:class
                          withBlock:didSelectItemBlock
                              named:@"collectionView_didSelect"];
    }
    
}
@end

