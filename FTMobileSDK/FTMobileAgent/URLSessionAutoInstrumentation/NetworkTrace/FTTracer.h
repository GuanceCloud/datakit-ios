//
//  FTTracer.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/3/17.
//  Copyright © 2021 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTMobileConfig.h"
#import "FTTracerProtocol.h"
NS_ASSUME_NONNULL_BEGIN
@interface FTTracer : NSObject<FTTracerProtocol>

-(instancetype)initWithConfig:(FTTraceConfig *)config;


@end

NS_ASSUME_NONNULL_END
