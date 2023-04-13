//
//  FTLog.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/5/19.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTEnumConstant.h"
#define FTLOG_MACRO(lvl, frmt, ...) \
[FTLog log : YES                                     \
     level : lvl                                     \
  function : __PRETTY_FUNCTION__                     \
      line : __LINE__                                \
    format : (frmt), ## __VA_ARGS__]

#define ZYDebug(...) ZYLog(__VA_ARGS__)

#define ZYLog(frmt,...)\
FTLOG_MACRO(StatusDebug,(frmt), ## __VA_ARGS__)

#define ZYErrorLog(frmt,...)\
FTLOG_MACRO(StatusError,(frmt), ## __VA_ARGS__)

#define FTCUSTOMLOG(lvl, frmt) \
[[FTLog sharedInstance] log : YES                                     \
   message : frmt                                     \
     level : lvl  ]

NS_ASSUME_NONNULL_BEGIN

@interface FTLog : NSObject

+ (instancetype)sharedInstance;
+ (void)enableLog:(BOOL)enableLog;
+ (BOOL)isLoggerEnabled;
+ (void)log:(BOOL)asynchronous
      level:(LogStatus)level
   function:(const char *)function
       line:(NSUInteger)line
     format:(NSString *)format, ... ;
- (void)log:(BOOL)asynchronous
    message:(NSString *)message
      level:(LogStatus)level;

@end

NS_ASSUME_NONNULL_END
