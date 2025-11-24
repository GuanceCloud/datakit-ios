//
//  TestWKWebViewVC.h
//  ft-sdk-iosTest
//
//  Created by hulilei on 2020/5/28.
//  Copyright © 2020 hll. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TestWKParentVC.h"

NS_ASSUME_NONNULL_BEGIN

@interface TestWKWebViewVC : TestWKParentVC
- (void)ft_loadOther:(NSString *)urlStr;
- (void)ft_reload;
- (void)ft_testNextLink;
- (void)ft_stopLoading;
- (void)test_addWebViewRumView:(void(^)(void))complete;
- (void)test_addWebViewRumViewNano:(void(^)(void))complete;
@end

NS_ASSUME_NONNULL_END
