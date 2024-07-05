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
@protocol FTWriter;
@interface FTSnapshotProcessor : NSObject

-(instancetype)initWithQueue:(dispatch_queue_t)queue writer:(id<FTWriter>)writer;
- (void)process:(FTViewTreeSnapshot *)viewTreeSnapshot touches:(NSMutableArray <FTTouchCircle *> *)touches;
@end

NS_ASSUME_NONNULL_END
