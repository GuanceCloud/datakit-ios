//
//  FTGlobal.m
//  FTMobileExtension
//
//  Created by hulilei on 2022/9/22.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
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


#import "FTGlobalManager.h"

@implementation FTGlobalManager
+ (instancetype)sharedInstance{
    static FTGlobalManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}
-(void)setRumConfig:(FTRumConfig *)rumConfig{
    _rumConfig = [rumConfig copy];
}
-(void)setTraceConfig:(FTTraceConfig *)traceConfig{
    _traceConfig = [traceConfig copy];
}
@end
