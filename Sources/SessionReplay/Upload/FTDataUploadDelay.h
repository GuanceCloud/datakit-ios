//
//  FTDataUploadDelay.h
//  SessionReplay
//
//  Created by hulilei on 2024/6/28.
//
//  Copyright 2024 Shanghai Guance Information Technology Co., Ltd.
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

#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@protocol FTUploadPerformancePreset;
@interface FTDataUploadDelay : NSObject
@property (nonatomic, assign,readwrite) NSTimeInterval current;
-(instancetype)initWithPerformance:(id<FTUploadPerformancePreset>)performance;
- (void)increase;
- (void)decrease;
@end

NS_ASSUME_NONNULL_END

#endif
