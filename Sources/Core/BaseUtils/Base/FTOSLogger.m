//
//  FTOSLogger.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/3/7.
//  Copyright 2024 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "FTOSLogger.h"
#import "FTLogMessage.h"
#import "FTInternalConstants.h"
#import <os/log.h>
#import "NSDate+FTUtil.h"

@interface FTOSLogger()
@property (nonatomic, strong) os_log_t logger;
@end
@implementation FTOSLogger

-(instancetype)init{
    self = [super init];
    if (self) {
        _logger = os_log_create("FTSDK", "InnerLog");
        _loggerQueue = dispatch_queue_create("com.ft.debugLog.console", NULL);
    }
    return self;
}
- (void)logMessage:(FTLogMessage *)logMessage {
    NSString *message = [self formatLogMessage:logMessage];
    NSString *dateStr = [logMessage.timestamp ft_stringWithBaseFormat];
    NSString *logContent = [NSString stringWithFormat:@"%@ %@",dateStr, message];

    switch (logMessage.level) {
        case StatusWarning:
        case StatusCritical:
        case StatusOk:
        case StatusCustom:
        case StatusInfo:
            os_log_info(self.logger,"%{public}s",[logContent UTF8String]);
            break;
        case StatusError:
            os_log_error(self.logger,"%{public}s",[logContent UTF8String]);
            break;
        case StatusDebug:
            os_log_debug(self.logger,"%{public}s",[logContent UTF8String]);
            break;
    }
}
@end
