//
//  UIEvent+Mock.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2025/2/7.
//  Copyright © 2025 GuanceCloud. All rights reserved.
//

#import "UIEvent+Mock.h"
@interface UIPressesEventMock:UIPressesEvent
@end
@implementation UIPressesEventMock{
    NSSet<UIPress *> *_allPresses;
}
-(instancetype)initWithAllPresses:(NSSet<UIPress*>*)presses{
    self = [super init];
    if(self){
        _allPresses = presses;
    }
    return self;
}
-(NSSet<UIPress *> *)allPresses{
    return _allPresses;
}
@end

@implementation UIPressesMock{
    UIPressPhase _phase;
    UIPressType _type;
    UIView *_view;
}
-(instancetype)initWithPhase:(UIPressPhase)phase type:(UIPressType)type view: (UIView*)view{
    self = [super init];
    if(self){
        _phase = phase;
        _type = type;
        _view = view;
    }
    return self;
}
-(UIPressPhase)phase{
    return _phase;
}
-(UIPressType)type{
    return _type;
}
-(UIResponder *)responder{
    return _view;
}
@end
@implementation UITouchMock{
    UITouchPhase _phase;
    UIView *_view;
    CGPoint _location;
}
-(instancetype)initWithPhase:(UITouchPhase)phase view:(UIView*)view location:(CGPoint)location{
    self = [super init];
    if(self){
        _phase = phase;
        _view = view;
        _location = location;
    }
    return self;
}
-(UITouchPhase)phase{
    return _phase;
}
-(UIView *)view{
    return _view;
}
-(CGPoint)locationInView:(UIView *)view{
    if (!_view || !view) {
        return _location;
    }
    return [_view convertPoint:_location toView:view];
}
@end
@interface UITouchEventMock:UIEvent
@end
@implementation UITouchEventMock{
    NSSet<UITouch *> *_allTouches;
}
-(instancetype)initWithAllTouches:(NSSet<UITouch*>*)touches{
    self = [super init];
    if(self){
        _allTouches = touches;
    }
    return self;
}
-(UIEventType)type{
    return UIEventTypeTouches;
}
-(NSSet<UITouch *> *)allTouches{
    return _allTouches;
}
@end
@implementation UIEvent (Mock)
+ (UIPressesEvent*)mockWithPress:(UIPress*)press{
    return [[UIPressesEventMock alloc]initWithAllPresses:[NSSet setWithArray:@[press]]];
}
+ (UIEvent*)mockWithTouch:(UITouch*)touch{
    return [self mockWithTouches:[NSSet setWithArray:@[touch]]];
}
+ (UIEvent*)mockWithTouches:(NSSet<UITouch*>*)touches{
    return [[UITouchEventMock alloc]initWithAllTouches:touches];
}
@end

