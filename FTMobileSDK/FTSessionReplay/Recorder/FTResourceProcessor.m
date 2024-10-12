//
//  FTResourceProcessor.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/12.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTResourceProcessor.h"
#import "FTSRWireframesBuilder.h"
#import "FTSRRecord.h"
#import "FTViewAttributes.h"
#import "FTFileWriter.h"
#import "FTResourceWriter.h"
#import "FTLog+Private.h"

@interface FTResourceProcessor()
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) id<FTResourcesWriting> resourceWriter;
@property (nonatomic, strong) NSMutableSet<NSString *> *processedIdentifiers;
@end
@implementation FTResourceProcessor
- (instancetype)initWithQueue:(dispatch_queue_t)queue resourceWriter:(id<FTResourcesWriting>)resourceWriter{
    self = [super init];
    if(self){
        _queue = queue;
        _resourceWriter = resourceWriter;
        _processedIdentifiers = [[NSMutableSet alloc]init];
    }
    return self;
}
- (void)process:(NSArray<id<FTSRResource>> *)resources context:(FTSRContext *)context{
    if(!resources || resources.count==0){
        return;
    }
    dispatch_async(self.queue, ^{
        @try {
            NSMutableArray *addResource = [NSMutableArray new];
            if(resources && resources.count>0){
                [resources enumerateObjectsUsingBlock:^(id<FTSRResource>  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    NSString *identifier = [obj calculateIdentifier];
                    if(![self.processedIdentifiers containsObject:identifier]){
                        [self.processedIdentifiers addObject:identifier];
                        FTEnrichedResource *resource = [[FTEnrichedResource alloc]init];
                        resource.identifier = identifier;
                        resource.data = [obj calculateData];
                        resource.appId = context.applicationID;
                        [addResource addObject:resource];
                    }
                }];
            }
            if(addResource.count>0){
                // resource 写入逻辑
                [self.resourceWriter write:addResource];
            }
            
        } @catch (NSException *exception) {
            FTInnerLogError(@"[Session Replay] EXCEPTION: %@", exception.description);
        }
    });
}
@end
