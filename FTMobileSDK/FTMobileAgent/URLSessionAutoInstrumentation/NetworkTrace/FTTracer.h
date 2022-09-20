//
//  FTTracer.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/3/17.
//  Copyright © 2021 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTTracerProtocol.h"
@class FTTraceConfig;
NS_ASSUME_NONNULL_BEGIN
@interface FTTracer : NSObject<FTTracerProtocol>

-(instancetype)initWithConfig:(FTTraceConfig *)config;
#if FTSDKUNITTEST
-(NSUInteger)getSkywalkingSeq;
#endif

@end

NS_ASSUME_NONNULL_END
