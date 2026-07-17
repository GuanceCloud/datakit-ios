//
//  FTRUMsessionHandler.h
//  FTMobileAgent
//
//  Created by hulilei on 2021/5/26.
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

#import "FTRUMHandler.h"
#import "FTRUMDependencies.h"
#import "FTRumDatasProtocol.h"
@class FTRUMMonitor,FTRUMContext;
NS_ASSUME_NONNULL_BEGIN

@interface FTRUMSessionHandler : FTRUMHandler
@property (nonatomic, strong) FTRUMDependencies *rumDependencies;
@property (nonatomic, strong, readonly) FTRUMContext *context;
@property (nonatomic, assign) FTAppState appState;

-(instancetype)initWithModel:(FTRUMDataModel *)model dependencies:(FTRUMDependencies *)dependencies;
-(instancetype)initWithExpiredSession:(FTRUMSessionHandler *)expiredSession time:(NSDate *)time;

-(nullable NSString *)getCurrentViewID;
-(NSDictionary *)getCurrentSessionInfo;
@end

NS_ASSUME_NONNULL_END
