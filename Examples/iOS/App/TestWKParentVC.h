//
//  TestWKParentVC.h
//  App
//
//  Created by hulilei on 2021/8/3.
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
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface TestWKParentVC : UIViewController
@property (nonatomic, strong) WKWebView *webView;
- (void)ft_load:(NSString *)urlStr;
- (void)test_loadRequestWithURL:(NSURL *)url;
- (void)test_loadHTMLString:(NSString *)string baseURL:(NSURL *)baseURL;
- (void)test_loadFileURL:(NSURL *)URL allowingReadAccessToURL:(NSURL *)readAccessURL;
- (void)setDelegateSelf;
- (void)setDelegateProxy;

@end

NS_ASSUME_NONNULL_END
