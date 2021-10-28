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

- (FTResourceContentModel *(^)(NSString *value))setResource_type{
    return ^(NSString *value) {
        self->_resource_type = value;
        return self;
    };
}
- (FTResourceContentModel *(^)(NSString *value))setResource_status{
    return ^(NSString *value) {
        self->_resource_status = value;
        return self;
    };
}
- (FTResourceContentModel *(^)(NSString *value))setResource_method{
    return ^(NSString *value) {
        self->_resource_method = value;
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
- (FTResourceContentModel *(^)(NSString *value))setError_type{
    return ^(NSString *value) {
        self->_error_type = value;
        return self;
    };
}
- (FTResourceContentModel *(^)(NSString *value))setError_situation{
    return ^(NSString *value) {
        self->_error_situation = value;
        return self;
    };
}

- (FTResourceContentModel *(^)(NSString *value))setError_message{
    return ^(NSString *value) {
        self->_error_message = value;
        return self;
    };
}
- (FTResourceContentModel *(^)(NSString *value))setError_stack{
    return ^(NSString *value) {
        self->_error_stack = value;
        return self;
    };
}

- (NSDictionary *)getResourceSuccessTags{
    NSMutableDictionary *dict = [[NSMutableDictionary alloc]init];
    [dict setValue:self.resource_type forKey:@"resource_type"];
    [dict setValue:self.resource_status forKey:@"resource_status"];
    [dict setValue:self.resource_method forKey:@"resource_method"];
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
    [dict setValue:self.resource_method forKey:@"resource_method"];
    [dict setValue:@"network" forKey:@"error_source"];
    [dict setValue:self.error_type forKey:@"error_type"];
    [dict setValue:self.error_situation forKey:@"error_situation"];
    return dict;
}
- (NSDictionary *)getResourceErrorFields{
    NSMutableDictionary *dict = [[NSMutableDictionary alloc]init];
    [dict setValue:self.error_message forKey:@"error_message"];
    [dict setValue:self.error_stack forKey:@"error_stack"];
    return dict;
}
@end