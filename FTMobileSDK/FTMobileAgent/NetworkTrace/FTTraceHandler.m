//
//  FTTraceHandler.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/10/13.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import "FTTraceHandler.h"
#import "FTBaseInfoHandler.h"
#import "FTGlobalRumManager.h"
#import "FTMobileAgent+Private.h"
#import "FTDateUtil.h"
#import "FTTraceHeaderManager.h"
#import "NSURLRequest+FTMonitor.h"
#import "FTJSONUtil.h"
#import "FTRUMManager.h"
#import "FTResourceContentModel.h"
#import "NSString+FTAdd.h"
#import "FTConfigManager.h"
@interface FTTraceHandler ()
@property (nonatomic, strong) NSDictionary *requestHeader;
@property (nonatomic, strong,nullable) NSError *error;
@property (nonatomic, strong) NSURLSessionTaskMetrics *metrics;
@property (nonatomic, strong) NSURLSessionTask *task;
@property (nonatomic, strong) NSData *data;
@property (nonatomic, strong, readwrite) NSURL *url;
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
- (NSDictionary *)getTraceHeader{
    if (!self.url) {
        return nil;
    }
    if (!_requestHeader) {
        __weak typeof(self) weakSelf = self;
        [[FTTraceHeaderManager sharedInstance] networkTrackHeaderWithUrl:self.url traceHeader:^(NSString * _Nullable traceId, NSString * _Nullable spanID, NSDictionary * _Nonnull header) {
            weakSelf.trace_id = traceId;
            weakSelf.span_id = spanID;
            weakSelf.requestHeader = header;
        }];
    }
    return _requestHeader;
}
@end
