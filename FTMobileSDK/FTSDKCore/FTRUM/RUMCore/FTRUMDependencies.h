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

//下列属性需要在 rumQueue 中进行 readwrite
@property (nonatomic, assign) BOOL currentSessionSample;
@property (nonatomic, assign) BOOL sessionHasReplay;
@property (nonatomic, assign) BOOL sampledForErrorReplay;
@property (nonatomic, assign) BOOL sampledForErrorSession;
@property (nonatomic, strong) NSDictionary *sessionReplaySampledFields;
@property (nonatomic, strong) NSDictionary *sessionReplayStats;
@end

NS_ASSUME_NONNULL_END
