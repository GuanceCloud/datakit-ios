//
//  FTRUMDependencies.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/5/10.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTRUMDataWriteProtocol.h"
#import "FTEnumConstant.h"
#import "FTRUMMonitor.h"
#import "FTFatalErrorContext.h"
NS_ASSUME_NONNULL_BEGIN

@interface FTRUMDependencies : NSObject
@property (nonatomic, assign) int sampleRate;
@property (nonatomic, assign) int sessionOnErrorSampleRate;
@property (nonatomic, assign) BOOL enableResourceHostIP;
@property (nonatomic, copy) NSString *appId;
@property (nonatomic, weak) id<FTRUMDataWriteProtocol> writer;
@property (nonatomic, assign) ErrorMonitorType errorMonitorType;
@property (nonatomic, strong) FTRUMMonitor *monitor;
@property (nonatomic, strong, nullable) FTFatalErrorContext *fatalErrorContext;
@property (atomic, assign) BOOL currentSessionSample;

@property (atomic, assign) BOOL sessionHasReplay;
@property (atomic, strong) NSDictionary *sessionReplayStats;
- (NSDictionary *)sampleFieldsDict;
@end

NS_ASSUME_NONNULL_END
