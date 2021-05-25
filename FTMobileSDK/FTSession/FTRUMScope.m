//
//  FTRUMScope.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/5/25.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTRUMScope.h"

@implementation FTRUMScope
- (NSMutableArray<FTRUMScope*>*)manage:(NSMutableArray<FTRUMScope*> *)childScopes byPropagatingCommand:(FTRUMModel *)command{
    NSMutableArray *newChildScopes = [NSMutableArray new];
    [[childScopes copy] enumerateObjectsUsingBlock:^(FTRUMScope *obj, NSUInteger idx, BOOL * _Nonnull stop) {
       BOOL success = [obj.assistant process:command];
        if (success) {
            [newChildScopes addObject:obj];
        }
    }];
    
    return newChildScopes;
}
@end
