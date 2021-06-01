//
//  FTPingThread.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/1/26.
//  Copyright © 2021 hll. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
typedef void(^FTPingBlock)(NSString *stackStr,NSDate *startDate,NSDate *endDate);

@interface FTPingThread : NSThread
@property (nonatomic, copy) FTPingBlock block;

@end

NS_ASSUME_NONNULL_END
