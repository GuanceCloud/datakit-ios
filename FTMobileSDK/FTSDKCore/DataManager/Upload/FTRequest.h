//
//  FTRequest.h
//  FTMacOSSDK
//
//  Created by 胡蕾蕾 on 2021/8/5.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
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
@property (nonatomic, strong) NSArray *events;
- (void)addHTTPHeaderFields:(NSMutableURLRequest *)mutableRequest packageId:(NSString *)packageId;
+(FTRequest * _Nullable)createRequestWithEvents:(NSArray *)events type:(NSString *)type;
@end

@interface FTLoggingRequest : FTRequest
@end

@interface FTRumRequest : FTRequest

@end
NS_ASSUME_NONNULL_END
