//
//  FTSessionTaskInterceptor.m
//  FTMobileAgent
//
//  Created by hulilei on 2021/10/13.
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

#import "FTSessionTaskHandler.h"
#import "FTTracerProtocol.h"
#import "FTResourceContentModel.h"
#import "FTResourceMetricsModel+Private.h"
#import "FTBaseInfoHandler.h"
#import "FTInnerLog.h"

@interface FTURLSessionRequestSnapshot ()
@property (nonatomic, strong, readwrite) NSURL *URL;
@property (nonatomic, copy, readwrite) NSString *HTTPMethod;
@property (nonatomic, copy, readwrite) NSDictionary<NSString *, NSString *> *allHTTPHeaderFields;
@property (nonatomic, strong, readwrite) NSData *HTTPBody;
@property (nonatomic, copy, readwrite) NSURLRequest *request;
- (instancetype)initWithURL:(NSURL *)URL
                 HTTPMethod:(nullable NSString *)HTTPMethod
        allHTTPHeaderFields:(nullable NSDictionary<NSString *, NSString *> *)allHTTPHeaderFields
                   HTTPBody:(nullable NSData *)HTTPBody NS_DESIGNATED_INITIALIZER;
@end

@implementation FTURLSessionRequestSnapshot
+ (instancetype)snapshotWithRequest:(NSURLRequest *)request{
    if (!request) {
        return nil;
    }
    @try {
        NSURL *URL = request.URL;
        if (!URL) {
            return nil;
        }
        return [[FTURLSessionRequestSnapshot alloc]initWithURL:URL
                                                    HTTPMethod:request.HTTPMethod
                                           allHTTPHeaderFields:request.allHTTPHeaderFields
                                                      HTTPBody:request.HTTPBody];
    }@catch (NSException *exception) {
        FTInnerLogError(@"exception: %@", exception);
        return nil;
    }
}
- (instancetype)initWithURL:(NSURL *)URL
                 HTTPMethod:(NSString *)HTTPMethod
        allHTTPHeaderFields:(NSDictionary<NSString *,NSString *> *)allHTTPHeaderFields
                   HTTPBody:(NSData *)HTTPBody{
    self = [super init];
    if (self) {
        _URL = URL;
        _HTTPMethod = [HTTPMethod copy];
        _allHTTPHeaderFields = [allHTTPHeaderFields copy];
        _HTTPBody = HTTPBody;
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
        if (_HTTPMethod) {
            request.HTTPMethod = _HTTPMethod;
        }
        request.allHTTPHeaderFields = _allHTTPHeaderFields;
        request.HTTPBody = _HTTPBody;
        _request = [request copy];
    }
    return self;
}
@end

@interface FTSessionTaskHandler ()
@property (nonatomic, strong) NSMutableData *mutableData;
@end
@implementation FTSessionTaskHandler
-(instancetype)init{
    return [self initWithIdentifier:[FTBaseInfoHandler randomUUID]];
}
-(instancetype)initWithIdentifier:(NSString *)identifier{
    self = [super init];
    if(self){
        _identifier = identifier;
    }
    return self;
}
- (void)setRequestSnapshot:(FTURLSessionRequestSnapshot *)requestSnapshot{
    _requestSnapshot = requestSnapshot;
    self.request = requestSnapshot.request;
}
- (void)taskReceivedData:(NSData *)data{
    if(!self.mutableData){
        self.mutableData = [NSMutableData dataWithData:data];
    }else{
        [self.mutableData appendData:data];
    }
}
- (void)taskReceivedMetrics:(NSURLSessionTaskMetrics *)metrics{
    [self taskReceivedMetrics:metrics custom:NO];
}
- (void)taskReceivedMetrics:(NSURLSessionTaskMetrics *)metrics custom:(BOOL)custom{
    FTResourceMetricsModel *metricsModel = nil;
    if (metrics) {
        metricsModel = [[FTResourceMetricsModel alloc]initWithTaskMetrics:metrics];
    }
    if(custom){
        metricsModel.resourceFetchTypeLocalCache = NO;
    }
    self.metricsModel = metricsModel;
}
- (void)taskCompletedWithResponse:(NSURLResponse *)response error:(NSError *)error{
    self.error = error;
    self.response = response;
    if (self.mutableData) {
        self.data = [self.mutableData copy];
        self.mutableData = nil;
    }
    FTResourceContentModel *model = [[FTResourceContentModel alloc]initWithRequest:self.request response:self.response data:self.data error:error];
    self.contentModel = model;
}
@end
