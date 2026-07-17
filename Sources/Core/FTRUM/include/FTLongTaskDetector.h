//
//  FTANRMonitor.h
//  FTMobileAgent
//
//  Created by hulilei on 2020/9/28.
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

NS_ASSUME_NONNULL_BEGIN
@protocol FTLongTaskProtocol<NSObject>
- (void)startLongTask:(long long)startTime;
- (void)updateLongTaskDate:(long long)time;
- (void)endLongTask;
@end
@interface FTLongTaskDetector : NSObject

/// How many milliseconds exceed for one longTask, default 250ms
@property (nonatomic, assign) long limitFreezeMillisecond;

-(instancetype)initWithDelegate:(id<FTLongTaskProtocol>)delegate;

//must be called from main thread
- (void)startDetecting;
- (void)stopDetecting;

@end

NS_ASSUME_NONNULL_END
