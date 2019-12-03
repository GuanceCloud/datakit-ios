//
//  Header.h
//  ft-sdk-ios
//
//  Created by 胡蕾蕾 on 2019/12/3.
//  Copyright © 2019 hll. All rights reserved.
//

#ifndef ZYLog_h
#define ZYLog_h
#define ZYDebug_Log
static inline void ZYLog(NSString * _Nullable format, ...) {
    __block va_list arg_list;
    va_start (arg_list, format);
    NSString *formattedString = [[NSString alloc] initWithFormat:format arguments:arg_list];
    va_end(arg_list);
    NSLog(@"[ZYLog]: %@", formattedString);
}
#ifdef  ZYDebug_Log
#define ZYDebug(...) ZYLog(__VA_ARGS__)
#else
#define ZYDebug(...)
#endif


#endif /* ZYLog_h */
