//
//  TestJsbridgeData.m
//  SampleApp
//
//  Created by hulilei on 2021/1/7.
//  Copyright © 2021 hll. All rights reserved.
//

#import "TestJsbridgeData.h"
#import <WebKit/WebKit.h>

@interface TestJsbridgeData ()
@property (nonatomic, strong) WKWebView *webView;

@end

@implementation TestJsbridgeData

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    self.title = @"TestJsbridgeData";
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
    if (@available(iOS 16.4, *)) {
        self.webView.inspectable = YES;
    }
    [self.view addSubview:self.webView];
//    NSString *path = [[NSBundle mainBundle]pathForResource:@"sample" ofType:@"html"];
    NSString *url = [[NSProcessInfo processInfo] environment][@"WEBVIEW_URL"];;
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
    [self.webView loadRequest:request];
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
