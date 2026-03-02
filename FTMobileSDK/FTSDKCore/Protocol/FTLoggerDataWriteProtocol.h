//
//  FTLoggerDataWriteProtocol.h
//  FTMobileSDK
//
//  Created by hulilei on 2023/5/26.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#ifndef FTLoggerDataWriteProtocol_h
#define FTLoggerDataWriteProtocol_h
NS_ASSUME_NONNULL_BEGIN
/// RUM data write interface
@protocol FTLoggerDataWriteProtocol <NSObject>

/// Logger data write
/// - Parameters:
///   - tags: Properties
///   - field: Metrics
///   - time: Data generation timestamp (ns)
-(void)loggingTags:(nullable NSDictionary *)tags field:(nullable NSDictionary *)field time:(long long)time linkRum:(BOOL)linkRum;

@end
NS_ASSUME_NONNULL_END

#endif /* FTLoggerDataWriteProtocol_h */
