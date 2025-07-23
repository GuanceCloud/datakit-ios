//
//  FTSessionReplayTouches.m
//  FTMobileAgent
//
//  Created by hulilei on 2022/12/23.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import "FTSessionReplayTouches.h"
#import "FTSwizzler.h"
#import "UITouch+FTIdentifier.h"
#import "FTWindowObserver.h"
#import "FTReadWriteHelper.h"
#import "NSDate+FTUtil.h"
#import "FTTouchSnapshot.h"
#import "UIView+FTSRPrivacy.h"
#import "FTSessionReplayPrivacyOverrides+Extension.h"
#import "FTThreadDispatchManager.h"

static FTSessionReplayTouches *touchesHandler;
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
        [FTThreadDispatchManager performBlockDispatchMainSyncSafe:^{
            touchesHandler = self;
        }];
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
            if (!touchesHandler) return;
            [touchesHandler handleEvent:event];
        }),FTSwizzlerModeOncePerClassAndSuperclasses,
                                 "ft_addScreenshot"
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
        if (touchesHandler == self) touchesHandler = nil;
    }];
}
-(void)dealloc{
    [self unSwizzleApplicationTouches];
}
@end
