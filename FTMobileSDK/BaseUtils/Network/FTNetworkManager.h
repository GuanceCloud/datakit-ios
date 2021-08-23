//
//  FTNetworkManager.h
//  FTMacOSSDK
//
//  Created by 胡蕾蕾 on 2021/8/2.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTRequest.h"

NS_ASSUME_NONNULL_BEGIN
typedef void (^FTNetworkSuccessBlock)(NSHTTPURLResponse *response,NSData *data);
typedef void (^FTNetworkFailureBlock)(NSHTTPURLResponse *response,NSData *data,NSError *error);
@interface FTNetworkManager : NSObject
+ (instancetype)sharedInstance;
- (void)sendRequest:(id<FTRequestProtocol>  _Nonnull)request
         completion:(void(^_Nullable)(NSHTTPURLResponse * _Nonnull httpResponse,
                                      NSData * _Nullable data,
                                      NSError * _Nullable error))callback;
@end

NS_ASSUME_NONNULL_END

