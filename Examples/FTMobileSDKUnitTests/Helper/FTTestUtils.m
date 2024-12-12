//
//  FTTestUtils.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2024/11/29.
//  Copyright © 2024 GuanceCloud. All rights reserved.
//

#import "FTTestUtils.h"
#import <QuartzCore/QuartzCore.h>

@implementation FTTestUtils
+ (CFTimeInterval)functionElapsedTime:(dispatch_block_t)block{
    CFTimeInterval startTime = CACurrentMediaTime();
    if (block) {
        block();
    }
    CFTimeInterval endTime = CACurrentMediaTime();
    return endTime - startTime;
}
@end
