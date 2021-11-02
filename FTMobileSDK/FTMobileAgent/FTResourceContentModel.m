//
//  FTResourceContentModel.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/10/27.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import "FTResourceContentModel.h"
#import "FTConstants.h"
@implementation FTResourceContentModel

- (FTResourceContentModel *(^)(NSString *value))setHttpMethod{
    return ^(NSString *value) {
        self->_httpMethod = value;
        return self;
    };
}
- (FTResourceContentModel *(^)(NSString *value))setResourceType{
    return ^(NSString *value) {
        self->_resourceType = value;
        return self;
    };
}
- (FTResourceContentModel *(^)(NSInteger value))setHttpStatusCode{
    return ^(NSInteger value) {
        self->_httpStatusCode = value;
        return self;
    };
}
- (FTResourceContentModel *(^)(NSInteger value))setErrorCode{
    return ^(NSInteger value) {
        self->_errorCode = value;
        return self;
    };
}
- (FTResourceContentModel *(^)(NSString *value))setResponseDataJsonStr{
    return ^(NSString *value) {
        self->_responseBody = value;
        return self;
    };
}
- (FTResourceContentModel *(^)(NSNumber *value))setResource_size{
    return ^(NSNumber *value) {
        self->_resource_size = value;
        return self;
    };
}
- (FTResourceContentModel *(^)(NSNumber *value))setResource_dns{
    return ^(NSNumber *value) {
        self->_resource_dns = value;
        return self;
    };
}
- (FTResourceContentModel *(^)(NSNumber *value))setResource_tcp{
    return ^(NSNumber *value) {
        self->_resource_tcp = value;
        return self;
    };
}
- (FTResourceContentModel *(^)(NSNumber *value))setResource_ssl{
    return ^(NSNumber *value) {
        self->_resource_ssl = value;
        return self;
    };
}
- (FTResourceContentModel *(^)(NSNumber *value))setResource_ttfb{
    return ^(NSNumber *value) {
        self->_resource_ttfb = value;
        return self;
    };
}
- (FTResourceContentModel *(^)(NSNumber *value))setResource_trans{
    return ^(NSNumber *value) {
        self->_resource_trans = value;
        return self;
    };
}
- (FTResourceContentModel *(^)(NSNumber *value))setResource_first_byte{
    return ^(NSNumber *value) {
        self->_resource_first_byte = value;
        return self;
    };
}
- (FTResourceContentModel *(^)(NSNumber *value))setDuration{
    return ^(NSNumber *value) {
        self->_duration = value;
        return self;
    };
}

- (NSDictionary *)getResourceSuccessTags{
    NSMutableDictionary *dict = [[NSMutableDictionary alloc]init];
    [dict setValue:self.httpMethod forKey:@"resource_method"];
    [dict setValue:self.resourceType forKey:@"resource_type"];
    [dict setValue:@(self.httpStatusCode) forKey:@"resource_status"];
    [dict setValue:self.httpMethod forKey:@"resource_method"];
    return dict;
}
- (NSDictionary *)getResourceSuccessFields{
    NSMutableDictionary *dict = [[NSMutableDictionary alloc]init];
    [dict setValue:self.resource_size forKey:@"resource_size"];
    [dict setValue:self.resource_dns forKey:@"resource_dns"];
    [dict setValue:self.resource_tcp forKey:@"resource_tcp"];
    [dict setValue:self.resource_ssl forKey:@"resource_ssl"];
    [dict setValue:self.resource_ttfb forKey:@"resource_ttfb"];
    [dict setValue:self.resource_trans forKey:@"resource_trans"];
    [dict setValue:self.resource_first_byte forKey:@"resource_first_byte"];
    [dict setValue:self.duration forKey:@"duration"];
    return dict;
}

- (NSDictionary *)getResourceErrorTags{
    NSMutableDictionary *dict = [[NSMutableDictionary alloc]init];
    [dict setValue:self.httpMethod forKey:@"resource_method"];
    [dict setValue:@(self.httpStatusCode) forKey:@"resource_status"];
    [dict setValue:@"network" forKey:@"error_source"];
    [dict setValue:@"network" forKey:@"error_type"];
    return dict;
}
- (NSDictionary *)getResourceErrorFields{
    NSMutableDictionary *dict = @{}.mutableCopy;
    if (self.responseBody) {
        [dict setValue:self.responseBody forKey:@"error_stack"];
    }
    return dict;
}
@end
