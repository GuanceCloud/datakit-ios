//
//  FTLongTaskANRData.h
//  FTMobileSDK
//
//  Created by hulilei on 2026/6/26.
//  Copyright © 2026 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTFatalErrorContext.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXTERN long long const FTLongTaskANRDataThresholdNs;
FOUNDATION_EXTERN long long const FTLongTaskANRDataUpdateIntervalNs;

@interface FTLongTaskANRData : NSObject
@property (nonatomic, assign) long long startTimeNs;
@property (nonatomic, assign) long long durationNs;
@property (nonatomic, copy, nullable) NSString *mainThreadBacktrace;
@property (nonatomic, copy, nullable) NSString *allThreadsBacktrace;
@property (nonatomic, strong, nullable) FTFatalErrorContextModel *errorContextModel;
@property (nonatomic, assign) long long lastUpdateTimeNs;

- (instancetype)initWithStartTimeNs:(long long)startTimeNs
                         durationNs:(long long)durationNs
                 mainThreadBacktrace:(nullable NSString *)mainThreadBacktrace
                 allThreadsBacktrace:(nullable NSString *)allThreadsBacktrace
                   errorContextModel:(nullable FTFatalErrorContextModel *)errorContextModel;
- (nullable instancetype)initWithDictionary:(NSDictionary *)dict;
- (NSDictionary *)convertToDictionary;
@end

@interface FTLongTaskANRDataStore : NSObject
@property (nonatomic, strong, readonly) dispatch_queue_t queue;
@property (nonatomic, strong, nullable) NSFileHandle *fileHandle;
@property (nonatomic, copy) NSString *dataStorePath;

- (void)appendData:(nullable NSData *)data;
- (void)deleteFile;
- (void)writeANRData:(FTLongTaskANRData *)anrData updateTimeNs:(long long)updateTimeNs resetFile:(BOOL)resetFile;
- (void)appendUpdateTimeNs:(long long)updateTimeNs;
- (nullable FTLongTaskANRData *)readANRData;
@end

NS_ASSUME_NONNULL_END
