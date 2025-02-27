//
//  XCTestCase+Utils.h
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2025/2/7.
//  Copyright © 2025 GuanceCloud. All rights reserved.
//

#import <XCTest/XCTest.h>

NS_ASSUME_NONNULL_BEGIN

@interface XCTestCase (Utils)
- (void)waitForTimeInterval:(NSTimeInterval)interval;
@end

NS_ASSUME_NONNULL_END
