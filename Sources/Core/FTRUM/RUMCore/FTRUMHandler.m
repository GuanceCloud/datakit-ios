//
//  FTRUMHandler.m
//  FTMobileAgent
//
//  Created by hulilei on 2021/5/25.
//  Copyright 2021 Shanghai Guance Information Technology Co., Ltd.
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

#import "FTRUMHandler.h"

@implementation FTRUMHandler
- (NSMutableArray<FTRUMHandler*>*)manageChildHandlers:(NSMutableArray<FTRUMHandler*> *)childHandlers byPropagatingData:(FTRUMDataModel *)data context:(nonnull NSDictionary *)context{
    NSMutableArray *newChildHandlers = [NSMutableArray new];
    [[childHandlers copy] enumerateObjectsUsingBlock:^(FTRUMHandler *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        BOOL success = [obj.assistant process:data context:context];
        if (success) {
            [newChildHandlers addObject:obj];
        }
    }];
    
    return newChildHandlers;
}
- (FTRUMHandler*)manage:(FTRUMHandler *)childHandler byPropagatingData:(FTRUMDataModel *)data context:(NSDictionary *)context{
    BOOL success = [childHandler.assistant process:data context:context];
     if (success) {
         return childHandler;
     }
    return nil;
}

@end
