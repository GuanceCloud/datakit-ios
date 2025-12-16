//
//  FTFatalErrorContext.m
//
//  Created by hulilei on 2024/4/30.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTFatalErrorContext.h"
@interface FTFatalErrorContext()
@end

@implementation FTFatalErrorContext
-(void)setLastSessionContext:(NSDictionary *)lastSessionContext{
    @synchronized (self) {
        if (_lastViewContext == nil && ![lastSessionContext isEqualToDictionary:_lastSessionContext]) {
            if (self.onChange) {
                self.onChange(lastSessionContext);
            }
        }
        _lastSessionContext = lastSessionContext;
    }
}
-(void)setLastViewContext:(NSDictionary *)lastViewContext{
    @synchronized (self) {
        if (![lastViewContext isEqualToDictionary:_lastViewContext]) {
            if (self.onChange) {
                self.onChange(lastViewContext);
            }
            _lastViewContext = lastViewContext;
        }
    }
}

@end
