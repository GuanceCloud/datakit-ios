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
typedef void(^TraceHeader)(NSString * _Nullable traceId, NSString *_Nullable spanID,NSDictionary *header);
@interface FTNetworkTraceManager : NSObject
@property (nonatomic, assign) BOOL enableLinkRumData;
@property (nonatomic, assign) FTNetworkTraceType networkTraceType;
@property (nonatomic, assign) BOOL enableAutoTrace;


+ (instancetype)sharedInstance;
- (void)setNetworkTrace:(FTTraceConfig *)traceConfig;
- (void)networkTrackHeaderWithUrl:(NSURL *)url traceHeader:(TraceHeader)traceHeader;
@end

NS_ASSUME_NONNULL_END
