//
//  SplitViewItemVC2.m
//  Example
//
//  Created by hulilei on 2021/9/26.
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

#import "SplitViewItemVC2.h"
#import "RumViewController.h"
#import "TabViewController.h"
#import "LoggingViewController.h"
#import "TraceViewController.h"
#import "WebViewController.h"
@interface SplitViewItemVC2 ()
@property (nonatomic, strong) TabViewController *mTabView;
@property (nonatomic, strong) RumViewController *mRumVC;
@property (nonatomic, strong) LoggingViewController *mLoggerVC;
@property (nonatomic, strong) TraceViewController *mTraceVC;
@property (nonatomic, strong) WebViewController *mWebViewVC;
@property (nonatomic, assign) NSInteger currentIndex;
@end

@implementation SplitViewItemVC2

- (void)viewDidLoad {
    [super viewDidLoad];
    [self insertChildViewController:self.mTabView atIndex:0];
    [self insertChildViewController:self.mPresent atIndex:1];
    [self insertChildViewController:self.mLoggerVC atIndex:2];
    [self insertChildViewController:self.mTraceVC atIndex:3];
    [self insertChildViewController:self.mWebViewVC atIndex:4];
    [self.view addSubview:self.mTabView.view];
}
-(RumViewController *)mPresent{
    if (!_mRumVC) {
        _mRumVC = [[RumViewController alloc]init];
    }
    return _mRumVC;
}
-(TabViewController *)mTabView{
    if (!_mTabView) {
        _mTabView = [[NSStoryboard storyboardWithName:@"Main" bundle:nil] instantiateControllerWithIdentifier:@"TabViewController"];
    }
    return _mTabView;
}
-(LoggingViewController *)mLoggerVC{
    if (!_mLoggerVC) {
        _mLoggerVC = [[LoggingViewController alloc]init];
    }
    return _mLoggerVC;
}
-(TraceViewController *)mTraceVC{
    if(!_mTraceVC){
        _mTraceVC = [[TraceViewController alloc]init];
    }
    return _mTraceVC;
}
-(WebViewController *)mWebViewVC{
    if(!_mWebViewVC){
        _mWebViewVC = [[WebViewController alloc]init];
    }
    return _mWebViewVC;
}
-(void)showViewIndex:(NSInteger)index{
    if (self.currentIndex != index) {
        NSViewController *from = [self getIndexVC:self.currentIndex];
        NSViewController *to = [self getIndexVC:index];
        [self transitionFromViewController:from toViewController:to options:NSViewControllerTransitionCrossfade completionHandler:^{
            self.currentIndex = index;
        }];
    }
   
}
- (NSViewController *)getIndexVC:(NSInteger)index{
    NSViewController *back;
    switch (index) {
        case 0:
            back = self.mTabView;
            break;
        case 1:
            back = self.mRumVC;
            break;
        case 2:
            back = self.mLoggerVC;
            break;
        case 3:
            back = self.mTraceVC;
            break;
        case 4:
            back = self.mWebViewVC;
            break;
        default:
            break;
    }
    return back;
}
@end
