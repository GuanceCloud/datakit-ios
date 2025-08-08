//
//  FTRUMAction.m
//  FTMobileSDK
//
//  Created by hulilei on 2025/7/30.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import "FTRUMAction.h"

@implementation FTRUMAction
-(instancetype)initWithActionName:(NSString *)actionName{
    return [self initWithActionName:actionName property:nil];
}
-(instancetype)initWithActionName:(NSString *)actionName property:(NSDictionary *)property{
    self = [super init];
    if (self) {
        _actionName = [actionName copy];
        _property = [property copy];
    }
    return self;
}
@end
