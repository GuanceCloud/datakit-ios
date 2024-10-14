//
//  FTRUMHandler.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/5/25.
//  Copyright © 2021 hll. All rights reserved.
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
