//
//  FTSnapshotProcessor.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/12.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@class FTViewTreeSnapshot,FTTouchSnapshot,FTResourceProcessor,FTRecordWriter;
@interface FTSnapshotProcessor : NSObject

-(instancetype)initWithQueue:(dispatch_queue_t)queue recordWriter:(FTRecordWriter *)recordWriter resourceProcessor:(FTResourceProcessor *)resourceProcessor;
- (void)process:(FTViewTreeSnapshot *)viewTreeSnapshot touchSnapshot:(nullable FTTouchSnapshot *)touchSnapshot;

@end

NS_ASSUME_NONNULL_END
