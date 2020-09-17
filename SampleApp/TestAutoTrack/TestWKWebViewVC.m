//
//  TestWKWebViewVC.m
//  ft-sdk-iosTest
//
//  Created by 胡蕾蕾 on 2020/5/28.
//  Copyright © 2020 hll. All rights reserved.
//

#import "TestWKWebViewVC.h"
#import <WebKit/WebKit.h>
#import <FTMobileAgent/WKWebView+FTTrace.h>
@interface TestWKWebViewVC ()<WKScriptMessageHandler,WKNavigationDelegate>
@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) WKWebView *webView2;

@end

@implementation TestWKWebViewVC
- (void)viewWillAppear:(BOOL)animated {
    
    [super viewWillAppear:animated];
    
    [_webView.configuration.userContentController addScriptMessageHandler:self name:@"track1"];
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    self.title = @"TestWKWebViewVC";
    //该方法 post body 会遗失
//    Class cls = NSClassFromString(@"WKBrowsingContextController");
//    SEL sel = NSSelectorFromString(@"registerSchemeForCustomProtocol:");
//    if ([(id)cls respondsToSelector:sel]) {
//        // 把 http 和 https 请求交给 NSURLProtocol 处理
//        [(id)cls performSelector:sel withObject:@"http"];
//        [(id)cls performSelector:sel withObject:@"https"];
//    }
    [self startTest];
}
- (void)startTest{
    WKUserContentController *userContentController = WKUserContentController.new;
    NSString *cookieSource = [NSString stringWithFormat:@"document.cookie = 'user=%@';", @"userValue"];

    WKUserScript *cookieScript = [[WKUserScript alloc] initWithSource:cookieSource injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:NO];
    [userContentController addUserScript:cookieScript];

    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    config.userContentController = userContentController;
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:@"https://github.com/CloudCare/dataflux-sdk-ios/tree/master"]];
        
    // 应用于 request 的 cookie 设置
    NSDictionary *headFields = request.allHTTPHeaderFields;
    NSString *cookie = headFields[@"user"];
    if (cookie == nil) {
      [request addValue:[NSString stringWithFormat:@"user=%@", @"userValue"] forHTTPHeaderField:@"Cookie"];
    }
    //! 使用configuration对象初始化webView
    self.webView = [[WKWebView alloc] initWithFrame:self.view.bounds configuration:config];
    [self.view addSubview:self.webView];
//    _webView.navigationDelegate = self;
    
    [self.webView ft_loadRequest:request];
//    _webView2 = [[WKWebView alloc] initWithFrame:CGRectMake(0, self.view.bounds.size.height/3+20, self.view.bounds.size.width, self.view.bounds.size.height/3) configuration:config];
//        [self.view addSubview:_webView2];
//    //    _webView.navigationDelegate = self;
//        
//    [_webView2 loadRequest:request];
    [_webView evaluateJavaScript:@"navigator.userAgent" completionHandler:^(id result, NSError *error) {
        
        NSLog(@"userAgent == %@",result);
    }];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.webView reload];
    });
    
}
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {

    
}

- (void)viewWillDisappear:(BOOL)animated {
    
    [super viewWillDisappear:animated];
    
    [_webView.configuration.userContentController removeScriptMessageHandlerForName:@"track1"];
}
///* 在发送请求之前，决定是否跳转 */
//- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler{
//   
//    //允许跳转
//    decisionHandler(WKNavigationActionPolicyAllow);
//    //不允许跳转
////    decisionHandler(WKNavigationActionPolicyCancel);
//}
//- (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler{
//   
//    decisionHandler(WKNavigationResponsePolicyAllow);
//}
-(void)dealloc{
    NSLog(@"dealloc");
}
/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
