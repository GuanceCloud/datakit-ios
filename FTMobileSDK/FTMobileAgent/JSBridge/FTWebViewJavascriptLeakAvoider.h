//
//  FTWebViewJavascriptLeakAvoider.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/1/6.
//  Copyright © 2021 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTWebViewJavascriptLeakAvoider : NSObject<WKScriptMessageHandler>
@property(nonatomic,weak)id <WKScriptMessageHandler>  delegate;
- (instancetype)initWithDelegate:(id <WKScriptMessageHandler> )delegate;

@end

NS_ASSUME_NONNULL_END
