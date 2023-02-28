//
//  FTTraceHandler.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/10/13.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import "FTTraceHandler.h"
#import "FTDateUtil.h"
#import "FTTracerProtocol.h"
#import "FTResourceContentModel.h"
#import "FTResourceMetricsModel.h"
@interface FTTraceHandler ()
@property (nonatomic, strong) NSDictionary *traceHeader;
@property (nonatomic, strong,nullable) NSError *error;
@property (nonatomic, strong) NSURLSessionTask *task;
@property (nonatomic, strong, readwrite) NSURL *url;
@property (nonatomic, strong) NSData *data;
@property (nonatomic, strong) NSDate *startTime;
@property (nonatomic, strong) NSNumber *duration;
@end
@implementation FTTraceHandler

-(instancetype)initWithUrl:(NSURL *)url identifier:(NSString *)identifier{
    self = [super init];
    if (self) {
        self.url = url;
        self.startTime = [NSDate date];
        self.duration = @0;
        self.identifier = identifier;
    }
    return self;
}
- (void)taskReceivedData:(NSData *)data{
    self.data = data;
}
- (void)taskReceivedMetrics:(NSURLSessionTaskMetrics *)metrics{
    FTResourceMetricsModel *metricsModel = nil;
    if (metrics) {
        metricsModel = [[FTResourceMetricsModel alloc]initWithTaskMetrics:metrics];
    }
    self.metricsModel = metricsModel;
}
- (void)taskCompleted:(NSURLSessionTask *)task error:(NSError *)error{
    NSHTTPURLResponse *response =(NSHTTPURLResponse *)task.response;
    FTResourceContentModel *model = [[FTResourceContentModel alloc]initWithRequest:task.currentRequest response:response data:self.data error:error];
    self.contentModel = model;
}
@end
