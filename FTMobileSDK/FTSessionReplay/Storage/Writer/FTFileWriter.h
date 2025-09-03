//
//  FTFileWriter.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/25.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@protocol FTAbstractJSONModelProtocol,FTFilesOrchestratorType;
@protocol FTWriter <NSObject>
- (void)write:(NSData *)datas;
- (void)write:(NSData *)datas forceNewFile:(BOOL)update;

@end
@protocol FTCacheWriter <NSObject,FTWriter>
- (void)active;
- (void)inactive;
- (void)cleanup;
@end
@interface FTFileWriter : NSObject<FTWriter>
-(instancetype)initWithOrchestrator:(id<FTFilesOrchestratorType>)orchestrator queue:(dispatch_queue_t)queue;
@end

NS_ASSUME_NONNULL_END
