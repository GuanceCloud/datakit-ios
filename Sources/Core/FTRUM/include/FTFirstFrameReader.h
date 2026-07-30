//
//  FTFirstFrameReader.h
//  FTMobileAgent
//
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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^FTFirstFrameCallback)(NSDate *date);
typedef NSDate * _Nonnull (^FTFirstFrameDateProvider)(void);
typedef CFTimeInterval (^FTFirstFrameMediaTimeProvider)(void);

/// One-shot reader for the first frame displayed after it starts.
///
/// Callback registration and CADisplayLink scheduling are serialized on the
/// main thread, so a frame cannot be consumed before its callback is installed.
API_UNAVAILABLE(macos)
@interface FTFirstFrameReader : NSObject

- (instancetype)init;
- (instancetype)initWithDateProvider:(FTFirstFrameDateProvider)dateProvider
                   mediaTimeProvider:(FTFirstFrameMediaTimeProvider)mediaTimeProvider NS_DESIGNATED_INITIALIZER;

- (void)startWithCallback:(FTFirstFrameCallback)callback;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
