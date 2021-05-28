//
//  FTRUMScope.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/5/25.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTRUMScope.h"

@implementation FTRUMScope
- (NSMutableArray<FTRUMScope*>*)manageChildScopes:(NSMutableArray<FTRUMScope*> *)childScopes byPropagatingCommand:(FTRUMCommand *)command{
    NSMutableArray *newChildScopes = [NSMutableArray new];
    [[childScopes copy] enumerateObjectsUsingBlock:^(FTRUMScope *obj, NSUInteger idx, BOOL * _Nonnull stop) {
       BOOL success = [obj.assistant process:command];
        if (success) {
            [newChildScopes addObject:obj];
        }
    }];
    
    return newChildScopes;
}
- (FTRUMScope*)manage:(FTRUMScope *)childScope byPropagatingCommand:(FTRUMCommand *)command{
    BOOL success = [childScope.assistant process:command];
     if (success) {
         return childScope;
     }
    return nil;
}

@end
