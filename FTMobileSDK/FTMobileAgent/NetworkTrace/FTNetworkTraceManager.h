//
//  FTNetworkTraceManager.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/3/17.
//  Copyright © 2021 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTMobileConfig.h"
NS_ASSUME_NONNULL_BEGIN
typedef void(^UnpackTraceHeaderHandler)(NSString *traceId, NSString *spanID,BOOL sampled);
@interface FTNetworkTraceManager : NSObject
@property (nonatomic, assign) BOOL enableLinkRumData;
@property (nonatomic, assign) FTNetworkTraceType networkTraceType;
@property (nonatomic, assign) BOOL enableAutoTrace;


+ (instancetype)sharedInstance;
- (BOOL)isTraceUrl:(NSURL *)url;
- (void)setNetworkTrace:(FTTraceConfig *)traceConfig;
- (NSDictionary *)networkTrackHeaderWithUrl:(NSURL *)url;
- (void)getTraceingDatasWithRequestHeaderFields:(NSDictionary *)headerFields handler:(UnpackTraceHeaderHandler)handler;
@end

NS_ASSUME_NONNULL_END
