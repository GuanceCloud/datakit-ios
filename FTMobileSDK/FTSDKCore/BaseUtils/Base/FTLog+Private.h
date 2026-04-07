//
//  FTLog+Private.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/3/7.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTInnerLog.h"
#import "FTLogMessage.h"

#define FT_CONSOLE_LOG(lvl,status,frmt,dict)   \
[[FTLog sharedInstance] userLog : YES                \
   message : frmt                                    \
     level : lvl                                     \
     status:status                                   \
   property: dict]

#define FTNSLogError(frmt, ...)    do{ if([FTLog isLoggerEnabled]) NSLog((frmt), ##__VA_ARGS__); } while(0)

NS_ASSUME_NONNULL_BEGIN

@class FTLogMessage;
@protocol FTDebugLogger <NSObject>
- (void)logMessage:(FTLogMessage *)logMessage NS_SWIFT_NAME(log(message:));
- (NSString *)formatLogMessage:(FTLogMessage *)logMessage;
@end


@interface FTLog ()
+ (void)enableLog:(BOOL)enableLog;
+ (void)addLogger:(id <FTDebugLogger>)logger;
+ (BOOL)isLoggerEnabled;
- (void)userLog:(BOOL)asynchronous
        message:(NSString *)message
          level:(LogStatus)level
         status:(NSString *)status
   property:(nullable NSDictionary *)property;
- (void)shutDown;
@end


@interface FTAbstractLogger : NSObject <FTDebugLogger>
{
    // Direct accessors to be used only for performance
    @public
    dispatch_queue_t _loggerQueue;
}
@property (nonatomic, strong) dispatch_queue_t loggerQueue;

@end
NS_ASSUME_NONNULL_END
