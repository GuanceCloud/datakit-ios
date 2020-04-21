//
//  FTURLProtocol.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/4/21.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTURLProtocol : NSURLProtocol
+ (void)startMonitor;

+ (void)stopMonitor;
@end

NS_ASSUME_NONNULL_END
