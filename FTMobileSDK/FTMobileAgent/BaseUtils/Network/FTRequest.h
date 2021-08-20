//
//  FTRequest.h
//  FTMacOSSDK
//
//  Created by 胡蕾蕾 on 2021/8/5.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTConstants.h"
#import "FTRequestBody.h"
@class FTRecordModel;
NS_ASSUME_NONNULL_BEGIN

@protocol FTRequestProtocol <NSObject>
@required

@property (nonatomic, strong, readonly) NSURL *absoluteURL;
@property (nonatomic, copy, readonly) NSString *path;
@property (nonatomic, copy, readonly) NSString *contentType;
@property (nonatomic, copy, readonly) NSString *httpMethod;
@optional
///event property
@property (nonatomic, strong) NSDictionary  *header;
@property (nonatomic, strong) id<FTRequestBodyProtocol> requestBody;
- (NSMutableURLRequest *)adaptedRequest:(NSMutableURLRequest *)mutableRequest;
@end

@interface FTRequest : NSObject<FTRequestProtocol>

-(instancetype)initWithEvents:(NSArray <FTRecordModel*>*)events type:(FTDataType)type;
@end

@interface FTLoggingRequest : FTRequest
@end

@interface FTRumRequest : FTRequest

@end
@interface FTObjectRequest : FTRequest

@end
@interface FTTracingRequest : FTRequest

@end
NS_ASSUME_NONNULL_END
