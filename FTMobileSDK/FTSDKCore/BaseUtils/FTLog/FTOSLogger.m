//
//  FTOSLogger.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/3/7.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTOSLogger.h"
#import "FTLogMessage.h"
#import "FTEnumConstant.h"
#import <os/log.h>
@interface FTOSLogger()
@property (nonatomic, strong) os_log_t logger;
@end
@implementation FTOSLogger

-(instancetype)init{
    self = [super init];
    if (self) {
        _logger = os_log_create("FTSDK", "InnerLog");
        _loggerQueue = dispatch_queue_create("com.guance.debugLog.console", NULL);
    }
    return self;
}
- (void)logMessage:(FTLogMessage *)logMessage {
    NSString *message = [self formatLogMessage:logMessage];
    switch (logMessage.level) {
        case StatusWarning:
        case StatusCritical:
        case StatusOk:
        case StatusInfo:
           os_log_info(self.logger,"%{public}s",[message UTF8String]);
           break;
        case StatusError:
            os_log_error(self.logger, "%{public}s",[message UTF8String]);
            break;
        case StatusDebug:
            os_log_debug(self.logger, "%{public}s",[message UTF8String]);
            break;
    }
}
@end
