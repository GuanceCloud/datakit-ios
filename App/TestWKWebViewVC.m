//
//  TestWKWebViewVC.m
//  ft-sdk-iosTest
//
//  Created by 胡蕾蕾 on 2020/5/28.
//  Copyright © 2020 hll. All rights reserved.
//

#import "TestWKWebViewVC.h"

@interface TestWKWebViewVC ()<WKNavigationDelegate>

@end

@implementation TestWKWebViewVC
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    self.title = @"TestWKWebViewVC";
}
-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    NSURL *url =  [[NSBundle mainBundle] URLForResource:@"sample" withExtension:@"html"];
    [self ft_load:url.absoluteString];
}

- (void)ft_loadOther:(NSString *)urlStr{
    NSMutableURLRequest *request2 = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:urlStr]];
    [self.webView loadRequest:request2];
}
- (void)ft_reload{
    [self.webView reload];
}
- (void)ft_testNextLink{
    [self.webView evaluateJavaScript:@"window.location.href = \"https://www.baidu.com\";" completionHandler:^(id result, NSError *error) {
        if (error == nil) {
            if (result != nil) {
            }
        } else {
            NSLog(@"evaluateJavaScript error : %@", error.localizedDescription);
        }
    }];
}
-(void)ft_stopLoading{
    [self.webView stopLoading];
}
- (void)test_addWebViewRumView{
    [self.webView evaluateJavaScript:@"testRumView()" completionHandler:^(id _Nullable response, NSError * _Nullable error) {
        //js函数调用return,这里才会有东西,否则无任何信息。
        NSLog(@"response: %@ error: %@", response, error);
    }];

}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler{

    decisionHandler(WKNavigationResponsePolicyAllow);
}
//- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error{
//
//}
//- (void)webView:(WKWebView *)webView didFailNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error{
//
//}
//- (void)webView:(WKWebView *)webView didFinishNavigation:(null_unspecified WKNavigation *)navigation{
//
//}
//- (void)webView:(WKWebView *)webView didCommitNavigation:(null_unspecified WKNavigation *)navigation{
//
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
