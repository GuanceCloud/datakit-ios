//
//  FTSessionReplayTouches.m
//  SessionReplay
//
//  Created by hulilei on 2022/12/23.
//
/*
 * This file is licensed under the Apache License Version 2.0.
 * This file contains software derived from software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 *
 * Modifications Copyright 2021 Shanghai Guance Information Technology Co., Ltd.
 * This file has been translated/adapted to Objective-C with project-specific changes.
 */

#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "FTSessionReplayTouches.h"
#import "FTSessionReplayCoreImports.h"
#import "UITouch+FTIdentifier.h"
#import "FTWindowObserver.h"
#import "FTTouchSnapshot.h"
#import "UIView+FTSRPrivacy.h"
#import "FTSessionReplayPrivacyOverrides+Extension.h"

static __weak FTSessionReplayTouches *ft_touchesHandler = nil;
static void *const kFTSRSendEvent = (void *)&kFTSRSendEvent;

@interface FTSessionReplayTouches()
/// Touch event collection, all operations on main thread, so no lock management needed
@property (nonatomic, strong) NSMutableArray *touches;
@property (nonatomic, assign) int currentID;
@property (nonatomic, strong) FTWindowObserver *windowObserver;
@end
@implementation FTSessionReplayTouches
-(instancetype)initWithWindowObserver:(FTWindowObserver *)observer{
    self = [super init];
    if(self){
        _touches = [[NSMutableArray alloc]init];
        _currentID = 0;
        _windowObserver = observer;
        [self swizzleApplicationTouches];
        ft_touchesHandler = self;
    }
    return self;
}
-(FTTouchSnapshot *)takeTouchSnapshotWithContext:(FTSRContext *)context{
    if(self.touches.count==0){
        return nil;
    }
    NSMutableArray *array = [NSMutableArray arrayWithArray:self.touches];
    [self.touches removeAllObjects];
    [array enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(FTTouchCircle *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if(![self shouldRecordTouch:obj context:context]){
            [array removeObjectAtIndex:idx];
        }
    }];
    if(array.count>0){
        return [[FTTouchSnapshot alloc]initWithTouches:array];
    }
    return nil;
}
- (BOOL)shouldRecordTouch:(FTTouchCircle*)touch context:(FTSRContext *)context{
    FTTouchPrivacyLevel privacy = touch.touchPrivacyOverride!=nil ?(FTTouchPrivacyLevel)[touch.touchPrivacyOverride intValue]:context.touchPrivacy;
    return privacy == FTTouchPrivacyLevelShow;
}
- (int)persistNextID:(UITouch *)touch{
    int newID = [self getNextID];
    touch.identifier = @(newID);
    return newID;
}
- (int)getNextID{
    int nextID = _currentID;
    _currentID = _currentID < UINT_MAX ?(_currentID+1):0;
    return nextID;
}
- (void)swizzleApplicationTouches{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        FTSwizzlerInstanceMethod(UIApplication.class,
                                 @selector(sendEvent:),
                                 FTSWReturnType(void),
                                 FTSWArguments(UIEvent *event),
                                 FTSWReplacement({
            FTSWCallOriginal(event);
            __strong FTSessionReplayTouches *touchesHandler = ft_touchesHandler;
            if (!touchesHandler) return;
            [touchesHandler handleEvent:event];
        }),FTSwizzlerModeOncePerClassAndSuperclasses,
                                 kFTSRSendEvent
                                 );
    });
}
- (void)handleEvent:(UIEvent *)event{
    UIWindow *window = self.windowObserver.keyWindow;
    if(event.type == UIEventTypeTouches){
        if(window){
            NSSet *set = [event touchesForWindow:window];
            NSEnumerator *en = [set objectEnumerator];
            UITouch *touch;
            while ((touch = en.nextObject) != nil) {
                if([touch.window isEqual:window]){
                    FTTouchPhase phase;
                    FTTouchCircle *circle = [[FTTouchCircle alloc]init];
                    switch (touch.phase) {
                        case UITouchPhaseBegan:
                        case UITouchPhaseRegionEntered:
                            touch.identifier = @([self persistNextID:touch]);
                            phase = TouchDown;
                            circle.identifier = [touch.identifier intValue];
                            break;
                        case UITouchPhaseMoved:
                        case UITouchPhaseStationary:
                        case UITouchPhaseRegionMoved:
                            if(touch.identifier == nil){
                                touch.identifier = @([self persistNextID:touch]);
                            }
                            phase = TouchMoved;
                            circle.identifier = [touch.identifier intValue];
                            break;
                        case UITouchPhaseEnded:
                        case UITouchPhaseCancelled:
                        case UITouchPhaseRegionExited:
                            phase = TouchUp;
                            if(touch.identifier == nil){
                                circle.identifier = [self getNextID];
                            }else{
                                circle.identifier = [touch.identifier intValue];
                                touch.identifier = nil;
                            }
                            break;
                    }
                    if (phase == TouchDown) {
                        NSNumber *touchPrivacy = [self resolveTouchOverride:touch];
                        if(touchPrivacy != nil){
                            touch.touchPrivacyOverride = touchPrivacy;
                        }
                    }
                    
                    CGPoint point = [touch locationInView:window];
                    circle.position = point;
                    circle.phase = phase;
                    circle.touchPrivacyOverride = touch.touchPrivacyOverride;
                    circle.timestamp = [NSDate ft_currentMillisecondTimeStamp];
                    [self.touches addObject:circle];
                }
            }
        }
    }
    
}
- (nullable NSNumber *)resolveTouchOverride:(UITouch *)touch{
    if (!touch.view) {
        return nil;
    }
    UIView *view = touch.view;
   
    while (view != nil) {
        NSNumber *touchPrivacy =  view.sessionReplayPrivacyOverrides.nTouchPrivacy;
        if(touchPrivacy != nil){
            return touchPrivacy;
        }
        view = view.superview;
    }
    return nil;
}
- (void)unSwizzleApplicationTouches{
    [FTThreadDispatchManager performBlockDispatchMainSyncSafe:^{
        [self.touches removeAllObjects];
        if (ft_touchesHandler == self) ft_touchesHandler = nil;
    }];
}
@end

#elif TARGET_OS_OSX

#import "FTSessionReplayTouches.h"
#import <AppKit/AppKit.h>
#import "FTSessionReplayCoreImports.h"
#import "FTSessionReplayPrivacyOverrides+Extension.h"
#import "FTTouchSnapshot.h"
#import "FTWindowObserver.h"
#import "NSView+FTSRPrivacy.h"

@interface FTSRMacOSPointerState : NSObject
@property (nonatomic, assign) int identifier;
@property (nonatomic, strong, nullable) NSNumber *touchPrivacyOverride;
@end

@implementation FTSRMacOSPointerState
@end

@interface FTSessionReplayTouches ()
/// AppKit sends local mouse events and the capture timer on the main thread.
/// Store only value snapshots here; never retain NSEvent or NSView past capture.
@property (nonatomic, strong) NSMutableArray<FTTouchCircle *> *touches;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, FTSRMacOSPointerState *> *activePointers;
@property (nonatomic, assign) int currentID;
@property (nonatomic, strong) FTWindowObserver *windowObserver;
@property (nonatomic, strong, nullable) id eventMonitor;
@end

@implementation FTSessionReplayTouches

- (instancetype)initWithWindowObserver:(FTWindowObserver *)observer {
    self = [super init];
    if (self) {
        _touches = [NSMutableArray array];
        _activePointers = [NSMutableDictionary dictionary];
        _currentID = 0;
        _windowObserver = observer;
        [self startMonitoringMouseEvents];
    }
    return self;
}

- (void)dealloc {
    id eventMonitor = _eventMonitor;
    if (eventMonitor) {
        [FTThreadDispatchManager performBlockDispatchMainSyncSafe:^{
            [NSEvent removeMonitor:eventMonitor];
        }];
    }
}

- (void)startMonitoringMouseEvents {
    NSEventMask eventMask = NSEventMaskLeftMouseDown
                          | NSEventMaskLeftMouseDragged
                          | NSEventMaskLeftMouseUp
                          | NSEventMaskRightMouseDown
                          | NSEventMaskRightMouseDragged
                          | NSEventMaskRightMouseUp
                          | NSEventMaskOtherMouseDown
                          | NSEventMaskOtherMouseDragged
                          | NSEventMaskOtherMouseUp;
    __weak typeof(self) weakSelf = self;
    [FTThreadDispatchManager performBlockDispatchMainSyncSafe:^{
        weakSelf.eventMonitor =
            [NSEvent addLocalMonitorForEventsMatchingMask:eventMask
                                                  handler:^NSEvent * _Nullable(NSEvent *event) {
                [weakSelf handleMouseEvent:event];
                return event;
            }];
    }];
}

- (void)handleMouseEvent:(NSEvent *)event {
    [self recordMouseEventType:event.type
                 buttonNumber:event.buttonNumber
             locationInWindow:event.locationInWindow
                       window:event.window];
}

- (void)recordMouseEventType:(NSEventType)type
                buttonNumber:(NSInteger)buttonNumber
            locationInWindow:(NSPoint)locationInWindow
                      window:(nullable NSWindow *)eventWindow {
    NSAssert(NSThread.isMainThread, @"Session Replay pointer capture must run on the main thread.");
    NSView *contentView = self.windowObserver.referenceView;
    NSWindow *keyWindow = contentView.window;
    if (!contentView || !keyWindow || eventWindow != keyWindow) {
        return;
    }

    FTTouchPhase phase;
    switch (type) {
        case NSEventTypeLeftMouseDown:
        case NSEventTypeRightMouseDown:
        case NSEventTypeOtherMouseDown:
            phase = TouchDown;
            break;
        case NSEventTypeLeftMouseDragged:
        case NSEventTypeRightMouseDragged:
        case NSEventTypeOtherMouseDragged:
            phase = TouchMoved;
            break;
        case NSEventTypeLeftMouseUp:
        case NSEventTypeRightMouseUp:
        case NSEventTypeOtherMouseUp:
            phase = TouchUp;
            break;
        default:
            return;
    }

    NSPoint pointInContentView = [contentView convertPoint:locationInWindow fromView:nil];
    NSNumber *button = @(buttonNumber);
    FTSRMacOSPointerState *pointerState = self.activePointers[button];

    if (!pointerState) {
        if (!NSPointInRect(pointInContentView, contentView.bounds)) {
            return;
        }
        pointerState = [FTSRMacOSPointerState new];
        pointerState.identifier = [self getNextID];
        pointerState.touchPrivacyOverride = [self resolveTouchOverrideAtPoint:pointInContentView
                                                                      inView:contentView];
        if (phase != TouchUp) {
            self.activePointers[button] = pointerState;
        }
    } else if (phase == TouchDown) {
        pointerState = [FTSRMacOSPointerState new];
        pointerState.identifier = [self getNextID];
        pointerState.touchPrivacyOverride = [self resolveTouchOverrideAtPoint:pointInContentView
                                                                      inView:contentView];
        self.activePointers[button] = pointerState;
    }

    NSPoint replayPoint = pointInContentView;
    replayPoint.x -= NSMinX(contentView.bounds);
    if (contentView.isFlipped) {
        replayPoint.y -= NSMinY(contentView.bounds);
    } else {
        replayPoint.y = NSMaxY(contentView.bounds) - pointInContentView.y;
    }

    FTTouchCircle *circle = [FTTouchCircle new];
    circle.position = replayPoint;
    circle.phase = phase;
    circle.identifier = pointerState.identifier;
    circle.timestamp = [NSDate ft_currentMillisecondTimeStamp];
    circle.touchPrivacyOverride = pointerState.touchPrivacyOverride;
    [self.touches addObject:circle];

    if (phase == TouchUp) {
        [self.activePointers removeObjectForKey:button];
    }
}

- (int)getNextID {
    int nextID = self.currentID;
    self.currentID = self.currentID < INT_MAX ? self.currentID + 1 : 0;
    return nextID;
}

- (nullable NSNumber *)resolveTouchOverrideAtPoint:(NSPoint)point inView:(NSView *)rootView {
    NSView *view = [rootView hitTest:point];
    while (view) {
        NSNumber *touchPrivacy = view.sessionReplayPrivacyOverrides.nTouchPrivacy;
        if (touchPrivacy) {
            return touchPrivacy;
        }
        view = view.superview;
    }
    return nil;
}

- (BOOL)shouldRecordTouch:(FTTouchCircle *)touch context:(FTSRContext *)context {
    FTTouchPrivacyLevel privacy = touch.touchPrivacyOverride
        ? (FTTouchPrivacyLevel)touch.touchPrivacyOverride.integerValue
        : context.touchPrivacy;
    return privacy == FTTouchPrivacyLevelShow;
}

- (FTTouchSnapshot *)takeTouchSnapshotWithContext:(FTSRContext *)context {
    NSAssert(NSThread.isMainThread, @"Session Replay pointer snapshot must run on the main thread.");
    if (self.touches.count == 0) {
        return nil;
    }
    NSArray<FTTouchCircle *> *pendingTouches = [self.touches copy];
    [self.touches removeAllObjects];

    NSMutableArray<FTTouchCircle *> *visibleTouches = [NSMutableArray array];
    for (FTTouchCircle *touch in pendingTouches) {
        if ([self shouldRecordTouch:touch context:context]) {
            [visibleTouches addObject:touch];
        }
    }
    if (visibleTouches.count > 0) {
        return [[FTTouchSnapshot alloc] initWithTouches:visibleTouches];
    }
    return nil;
}

@end

#endif
