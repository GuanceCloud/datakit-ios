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
typedef void (^Completion)(void);

@interface TestSessionDelegate : NSObject<NSURLSessionDelegate,NSURLSessionDataDelegate>
-(instancetype)initWithCompletionHandler:(Completion)completionHandler;
@end
@interface TestSessionDelegate_NoCollectingMetrics : NSObject<NSURLSessionDelegate,NSURLSessionDataDelegate>
-(instancetype)initWithCompletionHandler:(Completion)completionHandler;
@end
@interface TestSessionDelegate_OnlyCollectingMetrics : NSObject<NSURLSessionDelegate,NSURLSessionDataDelegate>

@end
@interface TestSessionDelegate_None : NSObject<NSURLSessionDelegate,NSURLSessionDataDelegate>

@end

@interface FTURLSessionCompleteTestDelegate : NSObject <NSURLSessionDelegate>
@property (nonatomic, assign) NSInteger URLSessionTaskDidCompleteWithErrorCalledCount;
@property (nonatomic, assign) NSInteger URLSessionDataTaskDidReceiveDataCalledCount;
@end

@interface FTURLSessionNoCompleteTestDelegate : NSObject <NSURLSessionDelegate>
@property (nonatomic, assign) NSInteger URLSessionTaskDidCompleteWithErrorCalledCount;
@property (nonatomic, assign) NSInteger URLSessionDataTaskDidReceiveDataCalledCount;
@end
@interface FTURLSessionNoDidFinishCollectingMetrics : NSObject <NSURLSessionDelegate>
@property (nonatomic, assign) NSInteger URLSessionTaskDidCompleteWithErrorCalledCount;
@property (nonatomic, assign) NSInteger URLSessionDataTaskDidReceiveDataCalledCount;
@end
NS_ASSUME_NONNULL_END
