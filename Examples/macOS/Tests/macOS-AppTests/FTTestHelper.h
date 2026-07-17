//
//  FTTestHelper.h
//  MacOSAppTests
//
//  Created by hulilei on 2023/5/9.
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

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSUInteger,TestClickView){
    ClickTableView_AutoTrack = 200,
    ClickTableView_Rum = 201,
    ClickTableView_ConsoleLog = 206,
    ClickTabViewItem_First = 300,
    ClickTabViewItem_Second = 301,
    ClickTabViewItem_Third = 302,
    ClickCollectionViewItem = 306,
    ClickCollectionViewItem2 = 308,
    ClickPopUpButton = 320,
    ClickComboBox = 321,
    ClickButtonCheck = 322,
    ClickSegmentedControl = 323,
    ClickStepper = 324,
    ClickLableGes = 325,
    ClickImageGes = 326,
};
@interface FTTestHelper : XCTestCase
- (void)clickView:(TestClickView)view;
- (void)clickAtView:(NSView *)view;
- (void)sleep:(NSInteger)time;
- (void)jumpToMainTestWindow;
@end

NS_ASSUME_NONNULL_END
