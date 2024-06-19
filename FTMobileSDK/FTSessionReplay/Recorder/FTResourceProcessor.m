//
//  FTResourceProcessor.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/12.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTResourceProcessor.h"
#import "FTSRWireframesBuilder.h"
@interface FTResourceProcessor()
@property (nonatomic, strong) NSMutableSet<NSString *> *processedIdentifiers;
@end
@implementation FTResourceProcessor
-(instancetype)init{
    self = [super init];
    if(self){
        _processedIdentifiers = [[NSMutableSet alloc]init];
    }
    return self;
}
- (void)process:(NSArray<id<FTSRResource>> *)resources context:(FTSRContext *)context{
    if(!resources){
        return;
    }
    dispatch_async(self.queue, ^{
        NSMutableArray *addResource = [NSMutableArray new];
        if(resources && resources.count>0){
            [resources enumerateObjectsUsingBlock:^(id<FTSRResource>  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                NSString *identifier = [obj calculateIdentifier];
                if(![self.processedIdentifiers containsObject:identifier]){
                    [self.processedIdentifiers addObject:identifier];
                    [addResource addObject:obj];
                }
            }];
        }
        if(addResource.count>0){
            // resource 写入逻辑
            
        }
    });
}
@end
