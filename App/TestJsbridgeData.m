//
//  TestJsbridgeData.m
//  SampleApp
//
//  Created by 胡蕾蕾 on 2021/1/7.
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
    
        
    //! 使用configuration对象初始化webView
    self.webView = [[WKWebView alloc] initWithFrame:self.view.bounds configuration:config];
    [self.view addSubview:self.webView];
//    NSString *path = [[NSBundle mainBundle]pathForResource:@"sample" ofType:@"html"];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://10.100.64.165/test/rum/"]];
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
