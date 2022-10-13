//
//  TestWKParentVC.h
//  App
//
//  Created by 胡蕾蕾 on 2021/8/3.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
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
