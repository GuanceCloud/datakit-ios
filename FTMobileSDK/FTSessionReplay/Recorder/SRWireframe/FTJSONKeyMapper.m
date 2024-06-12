//
//  FTJSONKeyMapper.m
//  FTMobileSDK
//
//  Created by hulilei on 2023/8/22.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import "FTJSONKeyMapper.h"

@implementation FTJSONKeyMapper
- (instancetype)initWithModelToJSONDictionary:(NSDictionary <NSString *, NSString *> *)toJSON{
    if (!(self = [super init]))
        return nil;

    _modelToJSONKeyBlock = ^NSString *(NSString *keyName)
    {
        return [toJSON valueForKeyPath:keyName] ?: keyName;
    };

    return self;
}
-(NSString *)convertValue:(NSString *)value{
    return _modelToJSONKeyBlock(value);
}
@end
