//
//  FTURLProtocol.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/4/21.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTAutoInterceptorProtocol.h"

@interface FTURLProtocol : NSURLProtocol

/// 设置 url 拦截代理
/// - Parameter delegate: url 会话拦截代理
+ (void)setDelegate:(id<FTAutoInterceptorProtocol>)delegate;

/// url 拦截代理
+ (id<FTAutoInterceptorProtocol>)delegate;

@end


