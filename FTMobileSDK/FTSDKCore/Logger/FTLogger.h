//
//  FTLogger.h
//  FTMobileSDK
//
//  Created by hulilei on 2023/5/24.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
#define FTLOGGER_MACRO(pro,lvl, frmt, ...) \
        [FTLogger log : lvl                     \
                  file: __FILE__                \
             function : __PRETTY_FUNCTION__     \
                 line : __LINE__                \
             property : (pro)              \
               format : (frmt), ## __VA_ARGS__]


#define FTLogInfo(frmt,...)  FTLogInfoProperty(@{}, frmt, ##__VA_ARGS__)
#define FTLogWarning(frmt,...) FTLogWarningProperty(@{},frmt, ##__VA_ARGS__)
#define FTLogError(frmt,...) FTLogErrorProperty(@{}, frmt , ##__VA_ARGS__)
#define FTLogCritical(frmt,...) FTLogCriticalProperty(@{},frmt, ##__VA_ARGS__)
#define FTLogOk(frmt,...) FTLogOkProperty(@{},frmt,##__VA_ARGS__)

#define FTLogInfoProperty(property,frmt,...) FTLOGGER_MACRO(property,0,(frmt), ## __VA_ARGS__)
#define FTLogWarningProperty(property,frmt,...) FTLOGGER_MACRO(property,1,(frmt), ## __VA_ARGS__)
#define FTLogErrorProperty(property,frmt,...) FTLOGGER_MACRO(property,2,(frmt), ## __VA_ARGS__)
#define FTLogCriticalProperty(property,frmt,...) FTLOGGER_MACRO(property,3,(frmt), ## __VA_ARGS__)
#define FTLogOkProperty(property,frmt,...) FTLOGGER_MACRO(property,4,(frmt), ## __VA_ARGS__)




@protocol FTLoggerProtocol <NSObject>
@optional
-(void)info:(NSString *)content property:(nullable NSDictionary *)property;
-(void)warning:(NSString *)content property:(nullable NSDictionary *)property;
-(void)error:(NSString *)content  property:(nullable NSDictionary *)property;
-(void)critical:(NSString *)content property:(nullable NSDictionary *)property;
-(void)ok:(NSString *)content property:(nullable NSDictionary *)property;

@end

@interface FTLogger : NSObject<FTLoggerProtocol>
+ (instancetype)sharedInstance;
+ (void)log:(NSInteger)status
         file:(const char *)file
     function:(const char *)function
         line:(NSUInteger)line
     property:(NSDictionary *)property
       format:(NSString *)format, ... ;

+ (void)log:(NSInteger)status
         file:(const char *)file
     function:(const char *)function
         line:(NSUInteger)line
     property:(NSDictionary *)property
       format:(NSString *)format
         args:(va_list)argList
NS_SWIFT_NAME(log(status:file:function:line:property:format:arguments:));

/// 关闭 logger
- (void)shutDown;
@end

NS_ASSUME_NONNULL_END
