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
@end

NS_ASSUME_NONNULL_END
