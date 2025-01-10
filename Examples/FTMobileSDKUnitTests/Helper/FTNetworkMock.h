//
//  FTNetworkMock.h
//  Examples
//
//  Created by hulilei on 2024/5/16.
//  Copyright © 2024 GuanceCloud. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OHHTTPStubs.h"

NS_ASSUME_NONNULL_BEGIN

@interface FTNetworkMock : NSObject
+ (void)registerUrlString:(NSString *)urlString;
+ (void)registerBeforeHandler:(void (^)(void))handler;
+ (void)registerHandler:(void (^)(void))handler;
+ (id<OHHTTPStubsDescriptor>)networkOHHTTPStubs;
+ (id<OHHTTPStubsDescriptor>)networkOHHTTPStubsHandler;
@end

NS_ASSUME_NONNULL_END
