//
//  FTThread.h
//
//  Created by hulilei on 2024/11/18.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class FTStackTrace;
@interface FTThread : NSObject
/**
 * Number of the thread
 */
@property (nonatomic, copy) NSNumber *threadId;

/**
 * Name (if available) of the thread
 */
@property (nullable, nonatomic, copy) NSString *name;

/**
 * FTStackTrace of the FTThread
 */
@property (nullable, nonatomic, strong) FTStackTrace *stackTrace;

/**
 * Did this thread crash?
 */
@property (nullable, nonatomic, copy) NSNumber *crashed;

/**
 * Was it the current thread.
 */
@property (nullable, nonatomic, copy) NSNumber *current;

/**
 * Was it the main thread?
 */
@property (nullable, nonatomic, copy) NSNumber *isMain;

/**
 * Initializes with its id
 * @param threadId NSNumber
 * @return SentryThread
 */
- (instancetype)initWithThreadId:(NSNumber *)threadId;
@end

NS_ASSUME_NONNULL_END
