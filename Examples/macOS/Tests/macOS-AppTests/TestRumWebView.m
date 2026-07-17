//
//  TestRumWebView.m
//  MacOSAppTests
//
//  Created by hulilei on 2023/10/9.
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

#import "TestRumWebView.h"
@interface TestRumWebView()<WKUIDelegate>

@end
@implementation TestRumWebView
-(void)loadView{
    self.view = [[NSView alloc]initWithFrame:NSMakeRect(0, 0, 1000, 800)];
}
-(void)viewDidLoad{
    [super viewDidLoad];
    [self loadWebView];
}
- (void)loadWebView{
    WKUserContentController *userContentController = WKUserContentController.new;
    NSString *cookieSource = [NSString stringWithFormat:@"document.cookie = 'user=%@';", @"userValue"];

    WKUserScript *cookieScript = [[WKUserScript alloc] initWithSource:cookieSource injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:NO];
    [userContentController addUserScript:cookieScript];

    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    config.userContentController = userContentController;
        
    //! Initialize webView using configuration object
    self.mWebView = [[WKWebView alloc] initWithFrame:self.view.bounds configuration:config];
    [self.view addSubview:self.mWebView];
    
}
- (void)test_loadUrl{
    NSURL *url =  [[NSBundle mainBundle] URLForResource:@"sample" withExtension:@"html"];
    [self.mWebView loadFileURL:url allowingReadAccessToURL:url];
}
- (void)test_addWebViewRumView:(void(^)(void))complete{
    [self.mWebView evaluateJavaScript:@"testRumView()" completionHandler:^(id _Nullable response, NSError * _Nullable error) {
        //JS function call return, only then will there be content, otherwise no information.
        NSLog(@"response: %@ error: %@", response, error);
        if(complete){
            complete();
        }
    }];

}
@end
