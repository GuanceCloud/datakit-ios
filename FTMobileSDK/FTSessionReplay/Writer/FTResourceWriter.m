//
//  FTResourceWriter.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/25.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTResourceWriter.h"
#import "FTSRRecord.h"
#import "FTFileWriter.h"
@interface FTResourceWriter()
@property (nonatomic, strong) NSMutableSet *knownIdentifiers;

@end
@implementation FTResourceWriter
- (instancetype)init{
    self = [super init];
    if(self){
        
    }
    return self;
}
- (void)write:(NSArray<FTEnrichedResource*>*)resources{
    NSMutableArray *filter = [NSMutableArray new];
    [resources enumerateObjectsUsingBlock:^(FTEnrichedResource * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if(![self.knownIdentifiers containsObject:obj.identifier]){
            [filter addObject:obj];
        }
    }];
    for (FTEnrichedResource *resource in filter) {
        [self.writer write:resource];
        [_knownIdentifiers addObject:resource.identifier];
    }
}
@end
