//
//  FTLogHook.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/6/15.
//  Copyright © 2020 hll. All rights reserved.
//
#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif
#import "FTLogHook.h"
#import "FTDateUtil.h"
#import "FTSDKCompat.h"
#import "FTLog.h"
static FTFishHookCallBack FTHookCallBack;
@interface FTLogHook ()
@property (nonatomic, assign) int errFd;
@property (nonatomic, assign) int outFd;
@property (nonatomic, copy) NSString *regexStr;
@property (nonatomic, strong) dispatch_queue_t concurrentQueue;
@property (nonatomic, strong) NSDateFormatter *consoletmf;
@end
@implementation FTLogHook
-(instancetype)init{
    self = [super init];
    if(self){
        _concurrentQueue = dispatch_queue_create("com.guance.logger", DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}
- (void)hookWithBlock:(FTFishHookCallBack)callBack{
   
    dispatch_async(self.concurrentQueue, ^{
        NSString *pname = [[NSProcessInfo processInfo] processName];
        self.regexStr = [NSString stringWithFormat:@"^\\d{4}-\\d{2}-\\d{2}\\s\\d{2}:\\d{2}:\\d{2}\\.\\d{6}\\+\\d{4}\\s%@\\[%d:\\d{1,}]",pname,[NSProcessInfo processInfo].processIdentifier];
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc]init];// 创建一个时间格式化对象2023-04-21 20:14:40.871026+0800
        [dateFormatter setDateFormat:@"YYYY-MM-dd HH:mm:ss.SSSSSS"];
        self.consoletmf = dateFormatter;
        FTHookCallBack = callBack;
        [self redirectSTD:STDERR_FILENO];
    });
}
- (void)redirectSTD:(int )fd {
    // 由于真机在断开数据线后会输出到 /dev/null 中, 这里要手动将buff设置为unbuffered
    setvbuf(stdout, NULL, _IONBF, 0);
    setvbuf(stderr, NULL, _IONBF, 0);
    self.outFd = dup(STDOUT_FILENO);
    self.errFd = dup(STDERR_FILENO);
    
    NSPipe *outPipe = [NSPipe pipe];
    NSFileHandle *pipeOutHandle = [outPipe fileHandleForReading] ;
    dup2([[outPipe fileHandleForWriting] fileDescriptor], STDOUT_FILENO);
    [pipeOutHandle readInBackgroundAndNotify];
    
    NSPipe *errPipe = [NSPipe pipe];
    NSFileHandle*pipeErrHandle = [errPipe fileHandleForReading];
    dup2([[errPipe fileHandleForWriting] fileDescriptor], STDERR_FILENO);
    [pipeErrHandle readInBackgroundAndNotify];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(redirectNotificationHandle:)
                                                 name:NSFileHandleReadCompletionNotification
                                               object:pipeOutHandle];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(redirectErrNotificationHandle:)
                                                 name:NSFileHandleReadCompletionNotification
                                               object:pipeErrHandle];
    @autoreleasepool {
        CFRunLoopRun();
    }
}
- (void)recoverStandardOutput{
    if(self.outFd>0){
        dup2(self.outFd, STDOUT_FILENO);
    }
    if(self.errFd>0){
        dup2(self.errFd, STDERR_FILENO);
    }
}
- (void)redirectNotificationHandle:(NSNotification *)nf {
    NSData *data = [[nf userInfo] objectForKey:NSFileHandleNotificationDataItem];
    NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ;
    //swift print 、printf 不用做过滤，直接回调
    if(str.length>0&&FTHookCallBack){
        FTHookCallBack(str,[FTDateUtil currentTimeNanosecond]);
    }
    write(self.outFd,str.UTF8String,strlen(str.UTF8String));
    [[nf object] readInBackgroundAndNotify];
}
//NSLog、os_log
- (void)redirectErrNotificationHandle:(NSNotification *)nf {
    NSData *data = [[nf userInfo] objectForKey: NSFileHandleNotificationDataItem];
    NSString *str = [[NSString alloc]initWithData:data encoding: NSUTF8StringEncoding];
    //如果开启 SDK 日志调试，需要进行过滤 SDK 内的调试日志
    if(str.length>0){
        [self matchString:str];
        write(self.errFd,str.UTF8String,strlen(str.UTF8String));
    }
    [[nf object] readInBackgroundAndNotify];
}

- (void)matchString:(NSString *)string{
    NSError *error;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:self.regexStr options:NSRegularExpressionAnchorsMatchLines error:&error];
    
    NSArray<NSTextCheckingResult *> * matches = [regex matchesInString:string options:0 range:NSMakeRange(0, [string length])];
    if(matches.count>0){
        [matches enumerateObjectsWithOptions:NSEnumerationConcurrent usingBlock:^(NSTextCheckingResult *match, NSUInteger idx, BOOL * _Nonnull stop) {
            NSString *component;
            if(idx == matches.count-1){
                component = [string substringFromIndex:match.range.location];
            }else{
                component = [string substringWithRange:NSMakeRange(match.range.location, matches[idx+1].range.location-match.range.location)];
            }
            if(![component containsString:@"[FTLog]"] && FTHookCallBack){
              
              NSDate *tm = [self.consoletmf dateFromString:[component substringToIndex:25]];
              FTHookCallBack(component,[FTDateUtil dateTimeNanosecond:tm]);
            }
        }];
    }
}

@end
