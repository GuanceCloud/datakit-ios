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
#import "FTErrorDataProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface FTRUMDependencies : NSObject
@property (nonatomic, assign) int sampleRate;
@property (nonatomic, assign) int sessionOnErrorSampleRate;
@property (nonatomic, assign) BOOL enableResourceHostIP;
@property (nonatomic, weak) id<FTRUMDataWriteProtocol> writer;
@property (nonatomic, strong) id<FTErrorMonitorInfoWrapper> errorMonitorInfoWrapper;
@property (nonatomic, strong) FTRUMMonitor *monitor;
@property (nonatomic, strong, nullable) FTFatalErrorContext *fatalErrorContext;
@property (atomic, strong) NSDictionary *linkRUMSessionContext;
@property (atomic, assign) BOOL currentSessionSample;

@end

NS_ASSUME_NONNULL_END
