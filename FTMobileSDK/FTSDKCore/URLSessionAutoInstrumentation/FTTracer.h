//
//  FTTracer.h
//  FTMobileAgent
//
//  Created by hulilei on 2021/3/17.
//  Copyright © 2021 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTTracerProtocol.h"
#import "FTEnumConstant.h"
NS_ASSUME_NONNULL_BEGIN

/// Specific implementation of trace functionality, adding parameters to request headers
@interface FTTracer : NSObject<FTTracerProtocol>
/// Set trace configuration
/// - Parameters:
///   - sampleRate: Sampling rate
///   - traceType: Link tracking type
///   - link: Whether to associate with rum
-(instancetype)initWithSampleRate:(int)sampleRate
                        traceType:(NetworkTraceType)traceType
                      serviceName:(NSString *)serviceName
                  enableAutoTrace:(BOOL)trace
                enableLinkRumData:(BOOL)link;
#if FTSDKUNITTEST
-(NSUInteger)getSkyWalkingSequence;
#endif

@end

NS_ASSUME_NONNULL_END
