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
- (void)write:(id<FTAbstractJSONModelProtocol>)data;
@end
@interface FTFileWriter : NSObject<FTWriter>
-(instancetype)initWithOrchestrator:(id<FTFilesOrchestratorType>)orchestrator queue:(dispatch_queue_t)queue;
@end

NS_ASSUME_NONNULL_END
