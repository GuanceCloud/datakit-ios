//
//  NSCollectionView+FTAutoTrack.h
//  FTSDK
//
//  Created by hulilei on 2021/9/17.
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

#import <TargetConditionals.h>
#if TARGET_OS_OSX
#import <Cocoa/Cocoa.h>
#import "FTAutoTrackProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSCollectionView (FTAutoTrack)<FTMacRUMActionProperty>
-(void)datakit_setDelegate:(id<NSCollectionViewDelegate>)delegate;
@end

@interface NSTableView (FTAutoTrack)<FTMacRUMActionProperty>

@end
NS_ASSUME_NONNULL_END
#endif
