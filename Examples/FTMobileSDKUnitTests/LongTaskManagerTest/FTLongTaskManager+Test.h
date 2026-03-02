//
//  FTLongTaskManager+Test.h
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2024/11/12.
//  Copyright © 2024 GuanceCloud. All rights reserved.
//

#import "FTLongTaskManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface FTLongTaskManager ()
@property (nonatomic, strong) NSFileHandle *fileHandle;
@property (nonatomic, copy) NSString *dataStorePath;
@property (nonatomic, strong) dispatch_queue_t queue;

- (void)deleteFile;
- (void)appendData:(NSData *)data;
- (void)updateLongTaskDate:(NSDate *)date;
- (void)startLongTask:(NSDate *)startDate;
- (void)endLongTask;
- (void)reportFatalWatchDogIfFound;
@end

NS_ASSUME_NONNULL_END
