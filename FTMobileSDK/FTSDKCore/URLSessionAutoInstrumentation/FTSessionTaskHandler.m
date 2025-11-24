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
- (void)taskCompleted:(NSURLSessionTask *)task error:(NSError *)error{
    self.error = error;
    self.response = task.response;
    if (self.mutableData) {
        self.data = [self.mutableData copy];
        self.mutableData = nil;
    }
    self.request = self.request?:task.currentRequest;
    FTResourceContentModel *model = [[FTResourceContentModel alloc]initWithRequest:self.request response:self.response data:self.data error:error];
    self.contentModel = model;
}
@end
