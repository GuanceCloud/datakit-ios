//
//  FTMonitorValue.h
//  FTMobileAgent
//
//  Created by hulilei on 2022/7/5.
//  Copyright 2022 Shanghai Guance Information Technology Co., Ltd.
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

/// Monitor value
@interface FTMonitorValue : NSObject<NSCopying>
/// Sample count
@property (nonatomic, assign) int sampleValueCount;
/// Sample minimum value
@property (nonatomic, assign ,readonly) double minValue;
/// Sample maximum value
@property (nonatomic, assign ,readonly) double maxValue;
/// Sample average value
@property (nonatomic, assign ,readonly) double meanValue;

/// Add sample value
/// - Parameter sample: Sample value
- (void)addSample:(double)sample;
/// Sample maximum minimum difference
- (double)greatestDiff;
/// Scale down proportionally
/// - Parameter scale: Scale down ratio
- (FTMonitorValue *)scaledDown:(double)scale;
@end

NS_ASSUME_NONNULL_END
