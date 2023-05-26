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
NS_ASSUME_NONNULL_BEGIN
@class FTLoggerConfig;

@interface FTLogger ()
+ (void)startWithEablePrintLogsToConsole:(BOOL)enable writer:(id<FTLoggerDataWriteProtocol>)writer;
- (void)log:(NSString *)message
     status:(LogStatus)status
   property:(nullable NSDictionary *)property;
@end

NS_ASSUME_NONNULL_END
