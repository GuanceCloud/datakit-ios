//
//  FTRUMViewHandler.h
//  FTMobileAgent
//
//  Created by hulilei on 2021/5/24.
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
NS_ASSUME_NONNULL_BEGIN
typedef void(^FTErrorHandled)(void);

@class FTRUMMonitor,FTRUMContext;

@interface FTRUMViewHandler : FTRUMHandler<FTRUMSessionProtocol>
@property (nonatomic, strong,readonly) FTRUMContext *context;
@property (nonatomic, assign,readwrite) BOOL isActiveView;
@property (nonatomic, copy) NSString *view_id;
@property (nonatomic, copy) NSString *view_name;
@property (nonatomic, copy) NSString *view_referrer;
@property (nonatomic, strong) NSNumber *loading_time;
@property (nonatomic, assign) BOOL fallbackView;

-(instancetype)initWithModel:(FTRUMViewModel *)model context:(FTRUMContext *)context rumDependencies:(FTRUMDependencies *)rumDependencies;

- (instancetype)initWithModel:(FTRUMViewModel *)model
                      context:(FTRUMContext *)context
              rumDependencies:(FTRUMDependencies *)rumDependencies
              needsMonitoring:(BOOL)needsMonitoring;
@end

NS_ASSUME_NONNULL_END
