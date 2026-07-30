//
//  FTFirstFrameReader.m
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

#import "FTSDKCompat.h"
#if FT_HAS_UIKIT
#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>
#import "FTFirstFrameReader.h"

@interface FTFirstFrameReader ()
@property (nonatomic, strong, nullable) CADisplayLink *displayLink;
@property (nonatomic, copy, nullable) FTFirstFrameCallback callback;
@property (nonatomic, copy) FTFirstFrameDateProvider dateProvider;
@property (nonatomic, copy) FTFirstFrameMediaTimeProvider mediaTimeProvider;
@property (nonatomic, assign) BOOL isActive;
@property (nonatomic, assign) BOOL hasStarted;
@end

@implementation FTFirstFrameReader

- (instancetype)init {
    return [self initWithDateProvider:^NSDate *{
        return [NSDate date];
    } mediaTimeProvider:^CFTimeInterval{
        return CACurrentMediaTime();
    }];
}

- (instancetype)initWithDateProvider:(FTFirstFrameDateProvider)dateProvider
                   mediaTimeProvider:(FTFirstFrameMediaTimeProvider)mediaTimeProvider {
    self = [super init];
    if (self) {
        _dateProvider = [dateProvider copy];
        _mediaTimeProvider = [mediaTimeProvider copy];
        _isActive = YES;
    }
    return self;
}

- (void)startWithCallback:(FTFirstFrameCallback)callback {
    __weak typeof(self) weakSelf = self;
    dispatch_block_t startBlock = ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || !strongSelf.isActive || strongSelf.hasStarted) {
            return;
        }

        // Install the callback before scheduling CADisplayLink. Once the link is
        // on the run loop, its selector can be invoked on the next main-loop turn.
        strongSelf.callback = callback;
        strongSelf.hasStarted = YES;
        strongSelf.displayLink = [CADisplayLink displayLinkWithTarget:strongSelf selector:@selector(displayLinkDidUpdate:)];
        [strongSelf.displayLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    };

    if (NSThread.isMainThread) {
        startBlock();
    } else {
        dispatch_async(dispatch_get_main_queue(), startBlock);
    }
}

- (void)displayLinkDidUpdate:(CADisplayLink *)displayLink {
    [self didUpdateFrameAtTimestamp:displayLink.timestamp];
}

- (void)didUpdateFrameAtTimestamp:(CFTimeInterval)timestamp {
    if (!self.isActive) {
        return;
    }

    NSDate *firstFrameDate = [self.dateProvider() dateByAddingTimeInterval:timestamp - self.mediaTimeProvider()];
    FTFirstFrameCallback callback = self.callback;
    self.isActive = NO;
    self.callback = nil;
    [self.displayLink invalidate];
    self.displayLink = nil;

    if (callback) {
        callback(firstFrameDate);
    }
}

- (void)stop {
    __weak typeof(self) weakSelf = self;
    dispatch_block_t stopBlock = ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        strongSelf.isActive = NO;
        strongSelf.callback = nil;
        [strongSelf.displayLink invalidate];
        strongSelf.displayLink = nil;
    };

    if (NSThread.isMainThread) {
        stopBlock();
    } else {
        dispatch_async(dispatch_get_main_queue(), stopBlock);
    }
}

- (void)dealloc {
    [_displayLink invalidate];
}

@end
#endif
