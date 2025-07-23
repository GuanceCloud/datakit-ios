//
//  FTANRMonitor.h
//  FTMobileAgent
//
//  Created by hulilei on 2020/9/28.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@protocol FTLongTaskProtocol<NSObject>
- (void)startLongTask:(NSDate *)startDate backtrace:(NSString *)backtrace;
- (void)updateLongTaskDate:(NSDate *)date;
- (void)endLongTask;
@end
@interface FTLongTaskDetector : NSObject

/// How many milliseconds exceed for one longTask, default 250ms
@property (nonatomic, assign) long limitFreezeMillisecond;

-(instancetype)initWithDelegate:(id<FTLongTaskProtocol>)delegate;

//must be called from main thread
- (void)startDetecting;
- (void)stopDetecting;

@end

NS_ASSUME_NONNULL_END
