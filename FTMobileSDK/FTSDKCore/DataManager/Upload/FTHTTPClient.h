//
//  FTHTTPClient.h
//  FTMacOSSDK
//
//  Created by 胡蕾蕾 on 2021/8/2.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTRequest.h"

NS_ASSUME_NONNULL_BEGIN
@interface FTHTTPClient : NSObject
-(instancetype)initWithTimeoutIntervalForRequest:(NSTimeInterval)timeOut NS_DESIGNATED_INITIALIZER;
- (void)sendRequest:(id<FTRequestProtocol>  _Nonnull)request
         completion:(void(^_Nullable)(NSHTTPURLResponse * _Nonnull httpResponse,
                                      NSData * _Nullable data,
                                      NSError * _Nullable error))callback;
@end

NS_ASSUME_NONNULL_END

