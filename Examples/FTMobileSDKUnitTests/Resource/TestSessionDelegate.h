//
//  TestSessionDelegate.h
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2024/1/24.
//  Copyright © 2024 GuanceCloud. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

NS_ASSUME_NONNULL_BEGIN

@interface TestSessionDelegate : NSObject<NSURLSessionDelegate,NSURLSessionDataDelegate>
-(instancetype)initWithTestExpectation:(XCTestExpectation *)expectation;
@end
@interface TestSessionDelegate_NoCollectingMetrics : NSObject<NSURLSessionDelegate,NSURLSessionDataDelegate>
-(instancetype)initWithTestExpectation:(XCTestExpectation *)expectation;

@end
@interface TestSessionDelegate_OnlyCollectingMetrics : NSObject<NSURLSessionDelegate,NSURLSessionDataDelegate>

@end
@interface TestSessionDelegate_None : NSObject<NSURLSessionDelegate,NSURLSessionDataDelegate>

@end
NS_ASSUME_NONNULL_END
