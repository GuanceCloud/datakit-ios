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

@interface FTLogger ()
+ (void)startWithEablePrintLogsToConsole:(BOOL)enable enableCustomLog:(BOOL)enableCustomLog logLevelFilter:(NSArray<NSNumber*>*)filter sampleRate:(int)sampletRate writer:(id<FTLoggerDataWriteProtocol>)writer;
- (void)log:(NSString *)message
     status:(LogStatus)status
   property:(nullable NSDictionary *)property;
- (void)syncProcess;
@end

NS_ASSUME_NONNULL_END
