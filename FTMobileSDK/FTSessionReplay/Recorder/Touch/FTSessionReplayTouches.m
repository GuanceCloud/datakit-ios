//
//  FTSessionReplayTouches.m
//  FTMobileAgent
//
//  Created by hulilei on 2022/12/23.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import "FTSessionReplayTouches.h"
#import "FTSwizzler.h"
#import "FTTouchCircle.h"
#import "UITouch+FTIdentifier.h"
#import "FTWindowObserver.h"
#import "FTReadWriteHelper.h"
@interface FTSessionReplayTouches()
/// 点击事件集合 都在主线程操作，所以不进行锁管理
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
    }
    return self;
}
-(NSMutableArray <FTTouchCircle *> *)takeTouches{
    NSMutableArray *array = [NSMutableArray arrayWithArray:self.touches];
    [self.touches removeAllObjects];
    return array;
}
- (int)getNextID{
    int nextID = _currentID;
    _currentID = _currentID + 1 < UINT_MAX ? :0;
    return nextID;
}
- (void)swizzleApplicationTouches{
    __weak typeof(self) weakSelf = self;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        FTSwizzlerInstanceMethod(UIApplication.class,
                                 @selector(sendEvent:),
                                 FTSWReturnType(void),
                                 FTSWArguments(UIEvent *event),
                                 FTSWReplacement({
            FTSWCallOriginal(event);
            [weakSelf handleEvent:event];
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
            FTTouchCircle *circle = [[FTTouchCircle alloc]init];
            while ((touch = en.nextObject) != nil) {
                if([touch.window isEqual:window]){
                    FTTouchPhase phase;
                    switch (touch.phase) {
                        case UITouchPhaseBegan:
                        case UITouchPhaseRegionEntered:
                            touch.identifier = [self getNextID];
                            phase = TouchDown;
                            circle.identifier = touch.identifier;
                            break;
                        case UITouchPhaseMoved:
                        case UITouchPhaseStationary:
                        case UITouchPhaseRegionMoved:
                            if(touch.identifier <= 0){
                                touch.identifier = [self getNextID];
                            }
                            phase = TouchMoved;
                            circle.identifier = touch.identifier;
                            break;
                        case UITouchPhaseEnded:
                        case UITouchPhaseCancelled:
                        case UITouchPhaseRegionExited:
                            phase = TouchUp;
                            if(touch.identifier <= 0){
                                circle.identifier = [self getNextID];
                            }else{
                                circle.identifier = touch.identifier;
                            }
                            break;
                    }
                    CGPoint point = [touch locationInView:window];
                    circle.position = point;
                    circle.phase = phase;
                    circle.timestamp = touch.timestamp*1000;
                    [self.touches addObject:circle];
                }
            }
        }
    }

}
- (void)unSwizzleApplicationTouches{
    [self.touches removeAllObjects];
}
@end
