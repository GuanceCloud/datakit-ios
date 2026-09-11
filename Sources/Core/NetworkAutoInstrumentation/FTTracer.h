//
//  FTTracer.h
//  FTMobileAgent
//
//  Created by hulilei on 2021/3/17.
//  Copyright 2021 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import <Foundation/Foundation.h>
#import "FTTracerProtocol.h"
#import "FTInternalConstants.h"
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
- (void)updateTraceSampleRate:(int)sampleRate;
#if FTSDKUNITTEST
-(NSUInteger)getSkyWalkingSequence;
#endif

@end

NS_ASSUME_NONNULL_END
