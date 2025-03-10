//
//  FTTestUtils.h
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2024/11/29.
//  Copyright © 2024 GuanceCloud. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTTestUtils : NSObject
+ (CFTimeInterval)functionElapsedTime:(dispatch_block_t)block;
+ (NSData *)transStreamToData:(NSInputStream *)inputStream;
+ (unsigned long long)base36ToDecimal:(NSString *)str;
@end

NS_ASSUME_NONNULL_END
