//
//  FTAutoTrackProtocol.h
//  Pods
//
//  Created by hulilei on 2021/9/16.
//  Copyright 2026 Shanghai Guance Information Technology Co., Ltd.
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

#ifndef FTAutoTrackProtocol_h
#define FTAutoTrackProtocol_h

#import <TargetConditionals.h>
#if TARGET_OS_OSX
#import <Foundation/Foundation.h>

@protocol FTMacRUMActionProperty <NSObject>
@optional
@property (nonatomic, copy, readonly) NSString *datakit_actionName;
//@property (nonatomic, weak, readonly) id datakit_controller;

@end
@protocol FTMacRumViewProperty <NSObject>
@property (nonatomic, strong) NSDate *datakit_viewLoadStartTime;
@property (nonatomic, strong) NSNumber *datakit_loadDuration;
@property (nonatomic, copy) NSString *datakit_viewUUID;
@property (nonatomic, copy, readonly) NSString *datakit_windowName;
@end

#endif


#endif /* FTAutoTrackProtocol_h */
