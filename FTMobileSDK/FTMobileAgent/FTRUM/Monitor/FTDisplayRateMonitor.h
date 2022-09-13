//
//  FTDisplayRate.h
//  FTMobileAgent
//
//  Created by hulilei on 2022/6/30.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
@class FTReadWriteHelper,FTMonitorValue;
NS_ASSUME_NONNULL_BEGIN

@interface FTDisplayRateMonitor : NSObject
- (void)addMonitorItem:(FTReadWriteHelper *)item;
- (void)removeMonitorItem:(FTReadWriteHelper *)item;
@end

NS_ASSUME_NONNULL_END
