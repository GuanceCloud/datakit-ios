//
//  FTWKWebViewHandler+SessionReplay.h
//  SessionReplay
//
//  Created by hulilei on 2025/11/13.
//
//  Copyright 2025 Shanghai Guance Information Technology Co., Ltd.
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

#import "FTSessionReplayCoreImports.h"

NS_ASSUME_NONNULL_BEGIN

@interface FTWKWebViewHandler (SessionReplay)
/// Keys that allow association with RUM data
@property (nonatomic, copy) NSArray *enableLinkRUMKeys;
/// A collection of slotIds for webViews that exist in memory but are not displayed on the window
@property (nonatomic, readwrite, strong) NSSet<NSNumber *> *hiddenSlotIds;
/// Actively initiate a web session replay operation to obtain the full view, only applicable to webViews displayed on the window
- (void)takeSubsequentFullSnapshot;
/// Associate info with the RUM data of the corresponding viewId
/// Web -> Native RUM
- (void)bindInfo:(nullable NSDictionary *)info viewId:(NSString *)viewId;
@end

NS_ASSUME_NONNULL_END

#endif
