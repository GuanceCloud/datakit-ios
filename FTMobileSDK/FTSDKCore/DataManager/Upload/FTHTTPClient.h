//
//  FTHTTPClient.h
//  FTMacOSSDK
//
//  Created by hulilei on 2021/8/2.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTRequest.h"

NS_ASSUME_NONNULL_BEGIN
FOUNDATION_EXPORT NSErrorDomain const FTHTTPClientErrorDomain;

typedef NS_ERROR_ENUM(FTHTTPClientErrorDomain, FTHTTPClientErrorCode) {
    FTHTTPClientErrorCodeRequestCreationFailed = 1,
};

@interface FTHTTPClient : NSObject
- (instancetype)initWithTimeoutIntervalForRequest:(NSTimeInterval)timeOut NS_DESIGNATED_INITIALIZER;
- (void)sendRequest:(id<FTRequestProtocol>  _Nonnull)request
         completion:(void(^_Nullable)(NSHTTPURLResponse * _Nullable httpResponse,
                                      NSData * _Nullable data,
                                      NSError * _Nullable error))callback;
@end

NS_ASSUME_NONNULL_END
