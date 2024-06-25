//
//  FTSnapshotProcessor.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/12.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@class FTViewTreeSnapshot,FTTouchCircle;
@interface FTSnapshotProcessor : NSObject
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, weak) id<FTWriter> writer;
- (void)process:(FTViewTreeSnapshot *)viewTreeSnapshot touches:(NSMutableArray <FTTouchCircle *> *)touches;
@end

NS_ASSUME_NONNULL_END
