//
//  FTHTTPClient.h
//  FTSDK
//
//  Created by hulilei on 2021/8/2.
//  Copyright 2021 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
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
