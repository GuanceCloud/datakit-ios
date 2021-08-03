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
- (void)setDelegateSelf;
- (void)setDelegateProxy;

@end

NS_ASSUME_NONNULL_END
