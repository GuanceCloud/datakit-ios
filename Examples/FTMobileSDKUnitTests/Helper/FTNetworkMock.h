//
//  FTNetworkMock.h
//  Examples
//
//  Created by hulilei on 2024/5/16.
//  Copyright © 2024 GuanceCloud. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTNetworkMock : NSObject
+ (void)registerUrlString:(NSString *)urlString;
+ (void)registerHandler:(void (^)(void))handler;
+ (void)networkOHHTTPStubs;
+ (void)networkOHHTTPStubsHandler;
+ (void)networkOHHTTPStubsHandler:(dispatch_block_t)block;
@end

NS_ASSUME_NONNULL_END
