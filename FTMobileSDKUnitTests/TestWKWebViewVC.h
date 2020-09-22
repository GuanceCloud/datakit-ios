//
//  TestWKWebViewVC.h
//  ft-sdk-iosTest
//
//  Created by 胡蕾蕾 on 2020/5/28.
//  Copyright © 2020 hll. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface TestWKWebViewVC : UIViewController
@property (nonatomic, strong) WKWebView *webView;
- (void)ft_load:(NSString *)urlStr;
- (void)ft_loadOther:(NSString *)urlStr;
- (void)ft_reload;
- (void)ft_testNextLink;
- (void)ft_testCrash;
@end

NS_ASSUME_NONNULL_END
