//
//  TestWKParentVC.m
//  App
//
//  Created by hulilei on 2021/8/3.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import "TestWKParentVC.h"
#import "TestWKProxy.h"
#import "TestWkWebViewHandler.h"

@interface TestWKParentVC ()<WKNavigationDelegate>
@property (nonatomic, strong) TestWKProxy *handler;
@end

@implementation TestWKParentVC

- (void)viewDidLoad {
    [super viewDidLoad];
    [self startTest];
}
- (void)startTest{
    WKUserContentController *userContentController = WKUserContentController.new;
    NSString *cookieSource = [NSString stringWithFormat:@"document.cookie = 'user=%@';", @"userValue"];

    WKUserScript *cookieScript = [[WKUserScript alloc] initWithSource:cookieSource injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:NO];
    [userContentController addUserScript:cookieScript];

    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    config.userContentController = userContentController;
    
        
    //! Initialize webView using configuration object
    self.webView = [[WKWebView alloc] initWithFrame:self.view.bounds configuration:config];
    [self.view addSubview:self.webView];
}
- (void)setDelegateSelf{
    self.webView.navigationDelegate = self;
}
-(void)setDelegateProxy{
    self.handler = [[TestWKProxy alloc]initWithWKWebViewTarget:[TestWkWebViewHandler sharedInstance]];
    self.webView.navigationDelegate = self.handler;
}
- (void)ft_load:(NSString *)urlStr{
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:urlStr]];
    [self.webView loadRequest:request];
}
- (void)test_loadRequestWithURL:(NSURL *)url{
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    [self.webView loadRequest:request];
}
- (void)test_loadHTMLString:(NSString *)string baseURL:(NSURL *)baseURL{
    [self.webView loadHTMLString:string baseURL:baseURL];
}
- (void)test_loadFileURL:(NSURL *)URL allowingReadAccessToURL:(NSURL *)readAccessURL{
    [self.webView loadFileURL:URL allowingReadAccessToURL:readAccessURL];
}
//- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler{
//    
//    decisionHandler(WKNavigationActionPolicyAllow);
//}
//- (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler{
//    
//    decisionHandler(WKNavigationResponsePolicyAllow);
//}
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
/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
