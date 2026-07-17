//
//  FTRequest.h
//  FTSDK
//
//  Created by hulilei on 2021/8/5.
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
#import "FTRequestBody.h"
#import "FTSerialNumberGenerator.h"
#import "FTPackageIdGenerator.h"
NS_ASSUME_NONNULL_BEGIN

@protocol FTRequestProtocol <NSObject>
@required

@property (nonatomic, strong, readonly) NSURL * _Nullable absoluteURL;
@property (nonatomic, copy, readonly) NSString * _Nullable path;
@property (nonatomic, copy, readonly) NSString *contentType;
@property (nonatomic, copy, readonly) NSString *httpMethod;
@property (nonatomic, copy, readonly, nullable) NSString *serialNumber;
@property (nonatomic, assign, readonly) BOOL enableDataIntegerCompatible;
@property (nonatomic, copy, readonly) NSString *userAgent;

- (FTSerialNumberGenerator *)classSerialGenerator;
@optional
///event property
@property (nonatomic, strong) id<FTRequestBodyProtocol> requestBody;
- (nullable NSMutableURLRequest *)adaptedRequest:(NSMutableURLRequest *)mutableRequest;
@end

@interface FTRequest : NSObject<FTRequestProtocol>
@property (nonatomic, strong, class) FTSerialNumberGenerator *serialGenerator;
@property (nonatomic, copy) NSArray *events;
- (void)addHTTPHeaderFields:(NSMutableURLRequest *)mutableRequest packageId:(nullable NSString *)packageId;
+(FTRequest * _Nullable)createRequestWithEvents:(NSArray *)events type:(NSString *)type;
@end

@interface FTLoggingRequest : FTRequest
@end

@interface FTRumRequest : FTRequest

@end
NS_ASSUME_NONNULL_END
