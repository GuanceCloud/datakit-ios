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
typedef void (^FirstFrameCallBack)(NSDate *date);

/// FPS monitor
@interface FTDisplayRateMonitor : NSObject
@property (nonatomic, copy, nullable) FirstFrameCallBack callBack;

- (NSDate *)firstFrameDate;

/// Add monitoring item, each ViewHandler in RUM contains a monitoring item to monitor data during the View lifecycle
/// - Parameter item: monitoring item
- (void)addMonitorItem:(FTReadWriteHelper *)item;

/// Remove monitoring item
/// - Parameter item: monitoring item
- (void)removeMonitorItem:(FTReadWriteHelper *)item;

/// Start DisplayLink
- (void)start;

/// Stop DisplayLink
- (void)stop;
@end

NS_ASSUME_NONNULL_END
