//
//  FTRequest.h
//  FTMacOSSDK
//
//  Created by 胡蕾蕾 on 2021/8/5.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTRequestBody.h"
@class FTRecordModel;
NS_ASSUME_NONNULL_BEGIN

@protocol FTRequestProtocol <NSObject>
@required

@property (nonatomic, strong, readonly) NSURL * _Nullable absoluteURL;
@property (nonatomic, copy, readonly) NSString * _Nullable path;
@property (nonatomic, copy, readonly) NSString *contentType;
@property (nonatomic, copy, readonly) NSString *httpMethod;
@optional
///event property
@property (nonatomic, strong) id<FTRequestBodyProtocol> requestBody;
- (NSMutableURLRequest *)adaptedRequest:(NSMutableURLRequest *)mutableRequest;
@end

@interface FTRequest : NSObject<FTRequestProtocol>

+(FTRequest * _Nullable)createRequestWithEvents:(NSArray <FTRecordModel*>*)events type:(NSString *)type;
@end

@interface FTLoggingRequest : FTRequest
@end

@interface FTRumRequest : FTRequest

@end
NS_ASSUME_NONNULL_END
