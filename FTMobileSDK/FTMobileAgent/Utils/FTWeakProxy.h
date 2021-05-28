//
//  FTWeakProxy.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/1/21.
//  Copyright © 2021 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTURLProtocol.h"

NS_ASSUME_NONNULL_BEGIN
@interface FTWeakProxy : NSProxy<FTHTTPProtocolDelegate>
@property (nullable, nonatomic, weak, readonly) id target;
- (instancetype)initWithTarget:(id)target;
+ (instancetype)proxyWithTarget:(id)target;
@end

NS_ASSUME_NONNULL_END
