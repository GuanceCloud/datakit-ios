//
//  FTSessionTaskInterceptor.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/10/13.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import "FTSessionTaskHandler.h"
#import "FTTracerProtocol.h"
#import "FTResourceContentModel.h"
#import "FTResourceMetricsModel+Private.h"
#import "FTBaseInfoHandler.h"
@interface FTSessionTaskHandler ()
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
    if(!self.data){
        self.data = [NSMutableData dataWithData:data];
    }else{
        [self.data appendData:data];
    }
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
    NSHTTPURLResponse *response =(NSHTTPURLResponse *)task.response;
    FTResourceContentModel *model = [[FTResourceContentModel alloc]initWithRequest:task.currentRequest response:response data:self.data error:error];
    self.contentModel = model;
}
@end
