//
//  FTRumView.m
//  FTMobileSDK
//
//  Created by hulilei on 2025/7/23.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import "FTRumView.h"

@implementation FTRumView
-(instancetype)initWithViewName:(NSString *)viewName{
    return [self initWithViewName:viewName property:nil];
}
- (instancetype)initWithViewName:(NSString *)viewName property:(NSDictionary *)property{
    self = [super init];
    if (self) {
        _viewName = viewName;
        _property = property;
    }
    return self;
}
@end
