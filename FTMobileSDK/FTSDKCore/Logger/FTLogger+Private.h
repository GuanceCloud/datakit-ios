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
#import "FTLoggerConfig.h"

NS_ASSUME_NONNULL_BEGIN

@interface FTLogger ()
@property (nonatomic, weak) id<FTLinkRumDataProvider> linkRumDataProvider;
/// Called when SDK starts, enables Logger
/// - Parameters:
///   - enable: Whether to output to console
///   - enableCustomLog: Whether to collect custom logs
///   - filter: Log filtering rules
///   - sampletRate: Collection rate
///   - writer: Data write object
+ (void)startWithLoggerConfig:(FTLoggerConfig *)config writer:(id<FTLoggerDataWriteProtocol>)writer;

/// Log input
/// - Parameters:
///   - content: Log content, can be json string
///   - status: Level and status
///   - property: Custom properties (optional)
- (void)log:(NSString *)content
 statusType:(FTLogStatus)statusType
   property:(nullable NSDictionary *)property;

/// Synchronously execute log processing queue
- (void)syncProcess;


- (void)updateWithRemoteConfiguration:(NSDictionary *)configuration;
@end

NS_ASSUME_NONNULL_END
