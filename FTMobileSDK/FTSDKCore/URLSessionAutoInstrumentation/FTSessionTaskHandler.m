//
//  FTSessionTaskInterceptor.m
//  FTMobileAgent
//
//  Created by hulilei on 2021/10/13.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import "FTSessionTaskHandler.h"
#import "FTTracerProtocol.h"
#import "FTResourceContentModel.h"
#import "FTResourceMetricsModel+Private.h"
#import "FTBaseInfoHandler.h"
static const NSUInteger FTMaxBufferedResponseBodySize = 512 * 1024;

@interface FTSessionTaskHandler ()
@property (nonatomic, strong) NSMutableData *mutableData;
@property (nonatomic, assign) BOOL responseBodyCacheDisabled;
@property (nonatomic, assign) BOOL responseBodyReceivedIncrementally;
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
- (nullable NSString *)normalizedMIMETypeWithResponse:(nullable NSURLResponse *)response{
    NSString *mimeType = response.MIMEType;
    if (mimeType.length == 0) {
        return nil;
    }
    NSString *type = [[mimeType componentsSeparatedByString:@";"].firstObject lowercaseString];
    return [type stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}
- (BOOL)shouldSkipResponseBodyCacheWithResponse:(nullable NSURLResponse *)response{
    NSString *mimeType = [self normalizedMIMETypeWithResponse:response];
    if (mimeType.length == 0) {
        return NO;
    }
    return [mimeType hasPrefix:@"image/"] ||
           [mimeType hasPrefix:@"video/"] ||
           [mimeType hasPrefix:@"audio/"] ||
           [mimeType isEqualToString:@"application/octet-stream"];
}
- (void)taskReceivedData:(NSData *)data{
    if(!data || data.length == 0 || self.responseBodyCacheDisabled){
        return;
    }
    self.responseBodyReceivedIncrementally = YES;
    if([self shouldSkipResponseBodyCacheWithResponse:self.response]){
        self.mutableData = nil;
        self.responseBodyCacheDisabled = YES;
        return;
    }
    NSUInteger bufferedLength = self.mutableData.length;
    if(bufferedLength > FTMaxBufferedResponseBodySize || data.length > FTMaxBufferedResponseBodySize - bufferedLength){
        self.mutableData = nil;
        self.responseBodyCacheDisabled = YES;
        return;
    }
    if(!self.mutableData){
        self.mutableData = [NSMutableData dataWithData:data];
    }else{
        [self.mutableData appendData:data];
    }
}
- (void)taskReceivedCompleteData:(NSData *)data{
    if(!data || data.length == 0){
        return;
    }
    self.data = data;
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
- (void)taskCompleted:(NSURLSessionTask *)task error:(NSError *)error{
    self.error = error;
    self.response = task.response;
    if(self.responseBodyReceivedIncrementally && ([self shouldSkipResponseBodyCacheWithResponse:self.response] || self.responseBodyCacheDisabled)){
        self.mutableData = nil;
        self.data = nil;
    }else if (self.mutableData) {
        self.data = [self.mutableData copy];
        self.mutableData = nil;
    }
    self.request = self.request?:task.currentRequest;
    FTResourceContentModel *model = [[FTResourceContentModel alloc]initWithRequest:self.request response:self.response data:self.data error:error];
    self.contentModel = model;
}
@end
