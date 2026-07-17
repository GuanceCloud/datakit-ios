//
//  FTMobileAgent+Private.h
//  FTMobileAgent
//
//  Created by hulilei on 2020/5/14.
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

#ifndef FTMobileAgent_Private_h
#define FTMobileAgent_Private_h


#import "FTMobileAgent.h"
#import <Foundation/Foundation.h>
@class FTPresetProperty,FTTracer;

@interface FTMobileAgent (Private)
/// Wait for all data being processed to complete
- (void)syncProcess;
/// Must be set before sessionReplay configuration
- (void)additionalConfigurationWithSource:(NSString *)source;
@end
#endif /* FTMobileAgent_Private_h */
