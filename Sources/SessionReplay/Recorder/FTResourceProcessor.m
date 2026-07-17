//
//  FTResourceProcessor.m
//  SessionReplay
//
//  Created by hulilei on 2024/6/12.
//
/*
 * This file is licensed under the Apache License Version 2.0.
 * This file contains software derived from software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 *
 * Modifications Copyright 2021 Shanghai Guance Information Technology Co., Ltd.
 * This file has been translated/adapted to Objective-C with project-specific changes.
 */

#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "FTResourceProcessor.h"
#import "FTSRNodeWireframesBuilder.h"
#import "FTSRRecord.h"
#import "FTViewAttributes.h"
#import "FTFileWriter.h"
#import "FTResourcesWriter.h"
#import "FTSessionReplayCoreImports.h"

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
                        resource.mimeType = obj.mimeType;
                        resource.bindInfo = context.bindInfo;
                        [addResource addObject:resource];
                    }
                }];
            }
            if(addResource.count>0){
                // resource writing logic
                [self.resourceWriter write:addResource];
            }
            
        } @catch (NSException *exception) {
            FTInnerLogError(@"[Session Replay] EXCEPTION: %@", exception.description);
        }
    });
}
@end

#endif
