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

- (void)dataflux_setDelegate:(id <UITableViewDelegate>)delegate {
    [self dataflux_setDelegate:delegate];
    if (self.delegate == nil) {
        return;
    }
    SEL selector = @selector(tableView:didSelectRowAtIndexPath:);
    Class class = [FTSwizzler realDelegateClassFromSelector:selector proxy:delegate];
    
    if ([FTSwizzler realDelegateClass:class respondsToSelector:selector]) {
        FTSwizzlerInstanceMethod(class,
                                 selector,
                                 FTSWReturnType(void),
                                 FTSWArguments(UITableView *tableView, NSIndexPath * indexPath),
                                 FTSWReplacement({
                                                     if (tableView && indexPath) {
                                                         UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
                                                         if([FTTrack sharedInstance].addRumDatasDelegate && [[FTTrack sharedInstance].addRumDatasDelegate respondsToSelector:@selector(addClickActionWithName:)]){
                                                             [[FTTrack sharedInstance].addRumDatasDelegate addClickActionWithName:cell.ft_actionName];
                                                         }
                                                     }
                                                     FTSWCallOriginal(tableView, indexPath);
                                                     
                                                 }),
                                 FTSwizzlerModeOncePerClassAndSuperclasses, 
                                 "tableView_didSelect");
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
        FTSwizzlerInstanceMethod(class,
                                 selector,
                                 FTSWReturnType(void),
                                 FTSWArguments(UICollectionView * collectionView, NSIndexPath * indexPath),
                                 FTSWReplacement({
                                                     if (collectionView && indexPath) {
                                                         UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
                                                         if([FTTrack sharedInstance].addRumDatasDelegate && [[FTTrack sharedInstance].addRumDatasDelegate respondsToSelector:@selector(addClickActionWithName:)]){
                                                             [[FTTrack sharedInstance].addRumDatasDelegate addClickActionWithName:cell.ft_actionName];
                                                         }
                                                     }
                                                     FTSWCallOriginal(collectionView, indexPath);
                                                 }),
                                 FTSwizzlerModeOncePerClassAndSuperclasses,
                                 "collectionView_didSelect");
    }
    
}
@end

