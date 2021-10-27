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
#pragma mark - RUM Resource Success 属性 -
@property (nonatomic, copy) NSString *resource_url_query;
@property (nonatomic, copy) NSString *resource_type;
@property (nonatomic, copy) NSString *resource_status_group;
@property (nonatomic, copy) NSString *resource_status;

#pragma mark - RUM Resource Success、Error 属性 -
@property (nonatomic, copy) NSString *resource_url;
@property (nonatomic, copy) NSString *resource_url_host;
@property (nonatomic, copy) NSString *resource_url_path;
@property (nonatomic, copy) NSString *resource_url_path_group;
@property (nonatomic, copy) NSString *resource_method;

#pragma mark - RUM Resource Success 指标 -
@property (nonatomic, strong) NSNumber *resource_size;
@property (nonatomic, strong) NSNumber *resource_dns;
@property (nonatomic, strong) NSNumber *resource_tcp;
@property (nonatomic, strong) NSNumber *resource_ssl;
@property (nonatomic, strong) NSNumber *resource_ttfb;
@property (nonatomic, strong) NSNumber *resource_trans;
@property (nonatomic, strong) NSNumber *resource_first_byte;
@property (nonatomic, strong) NSNumber *duration;

#pragma mark - Network Error 属性 -
@property (nonatomic, copy) NSString *error_type;
@property (nonatomic, copy) NSString *error_situation;

#pragma mark - Network Error 指标 -
@property (nonatomic, copy) NSString *error_message;
@property (nonatomic, copy) NSString *error_stack;


- (FTResourceContentModel *(^)(NSString *value))setResource_url_query;
- (FTResourceContentModel *(^)(NSString *value))setResource_type;
- (FTResourceContentModel *(^)(NSString *value))setResource_status_group;
- (FTResourceContentModel *(^)(NSString *value))setResource_status;

- (FTResourceContentModel *(^)(NSString *value))setResource_url;
- (FTResourceContentModel *(^)(NSString *value))setResource_url_host;
- (FTResourceContentModel *(^)(NSString *value))setResource_url_path;
- (FTResourceContentModel *(^)(NSString *value))setResource_url_path_group;
- (FTResourceContentModel *(^)(NSString *value))setResource_method;

- (FTResourceContentModel *(^)(NSNumber *value))setResource_size;
- (FTResourceContentModel *(^)(NSNumber *value))setResource_dns;
- (FTResourceContentModel *(^)(NSNumber *value))setResource_tcp;
- (FTResourceContentModel *(^)(NSNumber *value))setResource_ssl;
- (FTResourceContentModel *(^)(NSNumber *value))setResource_ttfb;
- (FTResourceContentModel *(^)(NSNumber *value))setResource_trans;
- (FTResourceContentModel *(^)(NSNumber *value))setResource_first_byte;
- (FTResourceContentModel *(^)(NSNumber *value))setDuration;

- (FTResourceContentModel *(^)(NSString *value))setError_type;
- (FTResourceContentModel *(^)(NSString *value))setError_situation;

- (FTResourceContentModel *(^)(NSString *value))setError_message;
- (FTResourceContentModel *(^)(NSString *value))setError_stack;


- (NSDictionary *)getResourceSuccessTags;
- (NSDictionary *)getResourceSuccessFields;

- (NSDictionary *)getResourceErrorTags;
- (NSDictionary *)getResourceErrorFields;

@end

NS_ASSUME_NONNULL_END
