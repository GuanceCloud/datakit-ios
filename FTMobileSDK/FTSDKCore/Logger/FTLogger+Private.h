//
//  FTLogger+Private.h
//  FTMobileSDK
//
//  Created by hulilei on 2023/5/26.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import "FTLogger.h"
#import "FTEnumConstant.h"
#import "FTLoggerDataWriteProtocol.h"
#import "FTLinkRumDataProvider.h"

NS_ASSUME_NONNULL_BEGIN
@class FTLoggerConfig;

@interface FTLogger ()

@property (nonatomic, weak) id<FTLinkRumDataProvider> linkRumDataProvider;
/// Called when SDK starts, enables Logger
/// - Parameters:
///   - enable: Whether to output to console
///   - enableCustomLog: Whether to collect custom logs
///   - filter: Log filtering rules
///   - sampletRate: Collection rate
///   - writer: Data write object
- (void)startWithLoggerConfig:(FTLoggerConfig *)config writer:(id<FTLoggerDataWriteProtocol>)writer;


/// Synchronously execute log processing queue
- (void)syncProcess;

/// Update dynamically configured settings obtained remotely
-(void)updateLoggerConfiguration:(FTLoggerConfig *)configuration;
@end

NS_ASSUME_NONNULL_END
