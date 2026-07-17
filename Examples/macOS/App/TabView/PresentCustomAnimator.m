//
//  PresentCustomAnimator.m
//  Example
//
//  Created by hulilei on 2021/9/10.
//  Copyright 2026 Shanghai Guance Information Technology Co., Ltd.
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

#import "PresentCustomAnimator.h"

@implementation PresentCustomAnimator
-(void)animatePresentationOfViewController:(NSViewController *)viewController fromViewController:(NSViewController *)fromViewController{
    NSViewController *bottomVC = fromViewController;
    NSViewController *topVC = viewController;
    topVC.view.wantsLayer = YES;
    topVC.view.alphaValue = 0;
    
    [bottomVC.view addSubview:topVC.view];
    
    topVC.view.layer.backgroundColor = [NSColor grayColor].CGColor;
    
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull context) {
        context.duration = 0.5;
        topVC.view.animator.alphaValue = 1;
    } completionHandler:nil];
}
- (void)animateDismissalOfViewController:(NSViewController *)viewController fromViewController:(NSViewController *)fromViewController{
    NSViewController *topVC = viewController;
    
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull context) {
        context.duration = 0.5;
        topVC.view.animator.alphaValue = 0;
    } completionHandler:^{
        [topVC.view removeFromSuperview];
    }];
}
@end
