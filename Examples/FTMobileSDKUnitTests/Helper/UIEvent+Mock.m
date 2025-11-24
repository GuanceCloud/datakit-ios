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
@implementation UIEvent (Mock)
+ (UIPressesEvent*)mockWithPress:(UIPress*)press{
    return [[UIPressesEventMock alloc]initWithAllPresses:[NSSet setWithArray:@[press]]];
}
@end



