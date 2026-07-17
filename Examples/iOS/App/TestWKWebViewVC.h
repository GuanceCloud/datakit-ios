//
//  TestWKWebViewVC.h
//  ft-sdk-iosTest
//
//  Created by hulilei on 2020/5/28.
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

#import <UIKit/UIKit.h>
#import "TestWKParentVC.h"

NS_ASSUME_NONNULL_BEGIN

@interface TestWKWebViewVC : TestWKParentVC
- (void)ft_loadOther:(NSString *)urlStr;
- (void)ft_reload;
- (void)ft_testNextLink;
- (void)ft_stopLoading;
- (void)test_addWebViewRumView:(void(^)(void))complete;
- (void)test_addWebViewRumViewNano:(void(^)(void))complete;
@end

NS_ASSUME_NONNULL_END
