//
//  TestWKWebViewVC.m
//  ft-sdk-iosTest
//
//  Created by 胡蕾蕾 on 2020/5/28.
//  Copyright © 2020 hll. All rights reserved.
//

#import "TestWKWebViewVC.h"

@interface TestWKWebViewVC ()<WKNavigationDelegate>
@property (nonatomic, strong) WKWebView *webView;

@end

@implementation TestWKWebViewVC
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    self.title = @"TestWKWebViewVC";
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
    self.webView.navigationDelegate = self;
    [self.view addSubview:self.webView];
    [self ft_load:@"https://github.com/CloudCare/dataflux-sdk-ios"];
}
- (void)ft_load:(NSString *)urlStr{
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:urlStr]];
    [self.webView loadRequest:request];
}

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
