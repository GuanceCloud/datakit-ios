//
//  FTJSONKeyMapper.m
//  SessionReplay
//
//  Created by hulilei on 2023/8/22.
//
//  Copyright 2023 Shanghai Guance Information Technology Co., Ltd.
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

#import <TargetConditionals.h>
#if TARGET_OS_IOS

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

#endif
