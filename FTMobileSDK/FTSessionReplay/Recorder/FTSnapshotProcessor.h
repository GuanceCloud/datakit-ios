//
//  FTSnapshotProcessor.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/12.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@class FTViewTreeSnapshot,FTTouchSnapshot,FTResourceProcessor;
@protocol FTWriter;
@interface FTSnapshotProcessor : NSObject

-(instancetype)initWithQueue:(dispatch_queue_t)queue writer:(id<FTWriter>)writer resourceProcessor:(FTResourceProcessor *)resourceProcessor;
- (void)process:(FTViewTreeSnapshot *)viewTreeSnapshot touchSnapshot:(nullable FTTouchSnapshot *)touchSnapshot;

- (void)changeWriter:(id<FTWriter>)writer needUpdateFullSnapshot:(BOOL)update;
@end

NS_ASSUME_NONNULL_END
