//
//  FTResourceContentModel.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/10/27.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTResourceContentModel : NSObject

@property (nonatomic, copy) NSString *httpMethod;
@property (nonatomic, copy) NSString *resourceType;
@property (nonatomic, assign) NSInteger httpStatusCode;
@property (nonatomic, strong) NSData *responseData;
@property (nonatomic, assign) NSInteger errorCode;
#pragma mark - Metrics -
//资源大小，默认单位：byte
@property (nonatomic, strong) NSNumber *resource_size;
//资源加载DNS解析时间 domainLookupEnd - domainLookupStart
@property (nonatomic, strong) NSNumber *resource_dns;
//资源加载TCP连接时间 connectEnd - connectStart
@property (nonatomic, strong) NSNumber *resource_tcp;
//资源加载SSL连接时间 connectEnd - secureConnectStart
@property (nonatomic, strong) NSNumber *resource_ssl;
//资源加载请求响应时间 responseStart - requestStart
@property (nonatomic, strong) NSNumber *resource_ttfb;
//资源加载内容传输时间 responseEnd - responseStart
@property (nonatomic, strong) NSNumber *resource_trans;
//资源加载首包时间 responseStart - domainLookupStart
@property (nonatomic, strong) NSNumber *resource_first_byte;
//资源加载时间 duration(responseEnd-fetchStartDate)
@property (nonatomic, strong) NSNumber *duration;



- (FTResourceContentModel *(^)(NSString *value))setHttpMethod;
- (FTResourceContentModel *(^)(NSString *value))setResourceType;
- (FTResourceContentModel *(^)(NSInteger value))setHttpStatusCode;
- (FTResourceContentModel *(^)(NSInteger value))setErrorCode;
- (FTResourceContentModel *(^)(NSData *value))setResponseData;


- (FTResourceContentModel *(^)(NSNumber *value))setResource_size;
- (FTResourceContentModel *(^)(NSNumber *value))setResource_dns;
- (FTResourceContentModel *(^)(NSNumber *value))setResource_tcp;
- (FTResourceContentModel *(^)(NSNumber *value))setResource_ssl;
- (FTResourceContentModel *(^)(NSNumber *value))setResource_ttfb;
- (FTResourceContentModel *(^)(NSNumber *value))setResource_trans;
- (FTResourceContentModel *(^)(NSNumber *value))setResource_first_byte;
- (FTResourceContentModel *(^)(NSNumber *value))setDuration;





- (NSDictionary *)getResourceSuccessTags;
- (NSDictionary *)getResourceSuccessFields;

- (NSDictionary *)getResourceErrorTags;
- (NSDictionary *)getResourceErrorFields;

@end

NS_ASSUME_NONNULL_END
