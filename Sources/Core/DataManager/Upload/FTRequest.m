//
//  FTRequest.m
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

#import "FTRequest.h"
#import "NSDate+FTUtil.h"
#import "FTNetworkInfoManager.h"
#import "FTRecordModel.h"
#import "FTConstants.h"
#import "FTBaseInfoHandler.h"
#import "FTDataCompression.h"
#import "FTInnerLog.h"
#import "FTInternalConstants.h"
#import "FTDataFilterManager.h"
#import "FTJSONUtil.h"
#import <objc/runtime.h>
@interface FTRequest()
- (BOOL)shouldAppendDisableServerFilter;
@end
@implementation FTRequest
+(void)initialize{
    if (self == [FTRequest class]) return;
    NSString *prefix = NSStringFromClass(self);
    self.serialGenerator = [[FTSerialNumberGenerator alloc] initWithPrefix:prefix];
}
+(FTRequest * _Nullable)createRequestWithEvents:(NSArray *)events type:(NSString *)type{
    if ([type isEqualToString:FT_DATA_TYPE_RUM]) {
        return [[FTRumRequest alloc]initWithEvents:events];
    }else if ([type isEqualToString:FT_DATA_TYPE_LOGGING]){
        return [[FTLoggingRequest alloc]initWithEvents:events];
    }
    return nil;
}
-(instancetype)initWithEvents:(NSArray<FTRecordModel *> *)events{
    self = [super init];
    if(self){
        self.events = events;
    }
    return self;
}
-(NSURL *)absoluteURL{
    FTNetworkConfigState state = [FTNetworkInfoManager sharedInstance].configState;
    NSString *urlString = nil;
    switch (state) {
        case FTNetworkConfigStateDatakitMode:
            urlString = [NSString stringWithFormat:@"%@%@",FTNetworkInfoManager.sharedInstance.datakitUrl,self.path];
            break;
        case FTNetworkConfigStateDatawayMode:
            urlString = [NSString stringWithFormat:@"%@%@?token=%@&to_headless=true",FTNetworkInfoManager.sharedInstance.datawayUrl,self.path,FTNetworkInfoManager.sharedInstance.clientToken];
            break;
        default:
            return nil;
    }
    if ([self shouldAppendDisableServerFilter]) {
        urlString = [urlString stringByAppendingFormat:[urlString containsString:@"?"] ? @"&%@" : @"?%@", @"disable_filter=true"];
    }
    return [NSURL URLWithString:urlString];
   
}
- (BOOL)shouldAppendDisableServerFilter{
    if ([FTNetworkInfoManager sharedInstance].configState != FTNetworkConfigStateDatakitMode ||
        ![self.path hasPrefix:@"/v1/write/"] ||
        ![FTDataFilterManager sharedInstance].shouldDisableServerFilter ||
        self.events.count == 0) {
        return NO;
    }
    for (id event in self.events) {
        if (![event isKindOfClass:FTRecordModel.class]) {
            return NO;
        }
        FTRecordModel *model = event;
        if (!model.remoteFilterChecked) {
            return NO;
        }
    }
    return YES;
}
-(NSString *)contentType{
    return @"text/plain;charset=UTF-8";
}
-(NSString *)httpMethod{
    return @"POST";
}
-(NSString *)path{
    return nil;
}
- (NSString *)userAgent{
    return [NSString stringWithFormat:@"%@/%@",FT_USER_AGENT_NAME,[FTNetworkInfoManager sharedInstance].sdkVersion];
}
-(nullable NSString *)serialNumber{
    return [[self classSerialGenerator] getCurrentSerialNumber];
}
- (FTSerialNumberGenerator *)classSerialGenerator{
    return [[self class] serialGenerator];
}
-(BOOL)enableDataIntegerCompatible{
    return FTNetworkInfoManager.sharedInstance.enableDataIntegerCompatible;
}
-(BOOL)compression{
    return FTNetworkInfoManager.sharedInstance.compression;
}
+ (FTSerialNumberGenerator *)serialGenerator {
    FTSerialNumberGenerator *generator = objc_getAssociatedObject(self, _cmd);
    if (!generator) {
        generator = [[FTSerialNumberGenerator alloc] init];
        objc_setAssociatedObject(self, _cmd, generator, OBJC_ASSOCIATION_RETAIN);
    }
    return generator;
}

+ (void)setSerialGenerator:(FTSerialNumberGenerator *)serialGenerator {
    objc_setAssociatedObject(self, @selector(serialGenerator), serialGenerator, OBJC_ASSOCIATION_RETAIN);
}
- (void)addHTTPHeaderFields:(NSMutableURLRequest *)mutableRequest packageId:(NSString *)packageId{
    NSDate *date = [NSDate date];
    NSString *gmtDate =[date ft_stringWithGMTFormat];
    [mutableRequest setValue:gmtDate forHTTPHeaderField:@"Date"];
    NSString *timestamp = [NSString stringWithFormat:@"%lld",[date ft_millisecondTimeStamp]];
    [mutableRequest setValue:timestamp forHTTPHeaderField:FT_HTTP_HEADER_X_CLIENT_TIMESTAMP];
    if(self.contentType){
        [mutableRequest setValue:self.contentType forHTTPHeaderField:@"Content-Type"];
    }
    [mutableRequest setValue:@"zh-CN" forHTTPHeaderField:@"Accept-Language"];
    [mutableRequest setValue:self.userAgent forHTTPHeaderField:@"User-Agent"];
    if (packageId) {
        [mutableRequest setValue:[NSString stringWithFormat:@"rumm-%@",packageId] forHTTPHeaderField:FT_HTTP_HEADER_X_PKG_ID];
    }
    [mutableRequest setValue:@"true" forHTTPHeaderField:FT_HTTP_HEADER_X_SDK_INTERNAL_REQUEST];
}
- (NSMutableURLRequest *)adaptedRequest:(NSMutableURLRequest *)mutableRequest{
    id<FTRequestBodyProtocol> requestBody = self.requestBody;
    if (!requestBody || !self.events) {
        return nil;
    }
    //Set header
    NSString *packageId = [FTPackageIdGenerator generatePackageId:self.serialNumber count:self.events.count];
    [self addHTTPHeaderFields:mutableRequest packageId:packageId];
    //Set request method
    mutableRequest.HTTPMethod = self.httpMethod;
    //body
    NSString *body = [requestBody getRequestBodyWithEventArray:self.events packageId:packageId enableIntegerCompatible:self.enableDataIntegerCompatible];
    mutableRequest.HTTPBody = [body dataUsingEncoding:NSUTF8StringEncoding];
    return [self compression:mutableRequest];
}
- (NSMutableURLRequest *)compression:(NSMutableURLRequest *)request{
    if(self.compression){
        NSData *data = [FTDataCompression deflate:request.HTTPBody];
        if (data) {
            request.HTTPBody = data;
            [request setValue:@"deflate" forHTTPHeaderField:@"Content-Encoding"];
        }else{
            FTInnerLogError(@"Failed to compress request payload \n- url: %@\n- uncompressed-size: %lu",request.URL,(unsigned long)request.HTTPBody.length);
        }
    }
    return request;
}
@end
@implementation FTLoggingRequest
-(id<FTRequestBodyProtocol>)requestBody{
    return [[FTRequestLineBody alloc]init];
}
-(NSString *)path{
    return @"/v1/write/logging";
}
@end
@interface FTRumRequest()
+ (NSArray *)deduplicatedRumViewEvents:(NSArray *)events;
+ (NSString *)rumViewIdForEvent:(FTRecordModel *)event;
@end
@implementation FTRumRequest
-(instancetype)initWithEvents:(NSArray<FTRecordModel *> *)events{
    self = [super initWithEvents:[FTRumRequest deduplicatedRumViewEvents:events]];
    return self;
}
-(id<FTRequestBodyProtocol>)requestBody{
    return [[FTRequestLineBody alloc]init];
}
-(NSString *)path{
    return @"/v1/write/rum";
}
+ (NSArray *)deduplicatedRumViewEvents:(NSArray *)events{
    if (events.count <= 1) {
        return events;
    }
    NSMutableDictionary<NSString *, NSNumber *> *selectedIndexes = [NSMutableDictionary dictionary];
    [events enumerateObjectsUsingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *viewId = [self rumViewIdForEvent:obj];
        if (viewId.length == 0) {
            return;
        }
        NSNumber *selectedIndex = selectedIndexes[viewId];
        if (!selectedIndex) {
            selectedIndexes[viewId] = @(idx);
            return;
        }
        FTRecordModel *selectedEvent = events[selectedIndex.unsignedIntegerValue];
        if (obj._id.longLongValue > selectedEvent._id.longLongValue) {
            selectedIndexes[viewId] = @(idx);
        }
    }];
    if (selectedIndexes.count == 0) {
        return events;
    }
    NSMutableArray *deduplicatedEvents = [NSMutableArray arrayWithCapacity:events.count];
    [events enumerateObjectsUsingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *viewId = [self rumViewIdForEvent:obj];
        NSNumber *selectedIndex = viewId.length > 0 ? selectedIndexes[viewId] : nil;
        if (!selectedIndex || selectedIndex.unsignedIntegerValue == idx) {
            [deduplicatedEvents addObject:obj];
        }
    }];
    return [deduplicatedEvents copy];
}
+ (NSString *)rumViewIdForEvent:(FTRecordModel *)event{
    if (![event isKindOfClass:FTRecordModel.class] || ![event.op isEqualToString:FT_DATA_TYPE_RUM]) {
        return nil;
    }
    NSDictionary *item = [FTJSONUtil dictionaryWithJsonString:event.data];
    if (![item isKindOfClass:NSDictionary.class]) {
        return nil;
    }
    NSDictionary *opdata = item[FT_OPDATA];
    if (![opdata isKindOfClass:NSDictionary.class]) {
        return nil;
    }
    NSString *sourceRaw = opdata[FT_KEY_SOURCE]?:opdata[FT_MEASUREMENT];
    if (![sourceRaw isKindOfClass:NSString.class] || ![sourceRaw isEqualToString:FT_RUM_SOURCE_VIEW]) {
        return nil;
    }
    NSDictionary *tags = opdata[FT_TAGS];
    if (![tags isKindOfClass:NSDictionary.class]) {
        return nil;
    }
    NSString *viewId = tags[FT_KEY_VIEW_ID];
    return [viewId isKindOfClass:NSString.class] ? viewId : nil;
}
@end
