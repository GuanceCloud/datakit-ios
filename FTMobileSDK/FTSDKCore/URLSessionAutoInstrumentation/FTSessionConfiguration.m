//
//  FTSessionConfiguration.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/4/21.
//  Copyright © 2020 hll. All rights reserved.
//
#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif
#import "FTSessionConfiguration.h"
#import <objc/runtime.h>
#import "FTURLProtocol.h"
#import "FTSwizzle.h"
#import "NSURLSessionConfiguration+FTSwizzler.h"
@interface FTURLSessionTaskInfo : NSObject
- (instancetype)initWithTask:(NSURLSessionDataTask *)task delegate:(id<NSURLSessionDataDelegate>)delegate modes:(NSArray *)modes;
@property (atomic, strong, readonly ) NSURLSessionDataTask *        task;
@property (atomic, strong, readonly ) id<NSURLSessionDataDelegate>  delegate;
@property (atomic, strong, readonly ) NSThread *                    thread;
@property (atomic, copy,   readonly ) NSArray *                     modes;
- (void)performBlock:(dispatch_block_t)block;
- (void)invalidate;
@end
@interface FTURLSessionTaskInfo ()
@property (atomic, strong, readwrite) id<NSURLSessionDataDelegate>  delegate;
@property (atomic, strong, readwrite) NSThread *                    thread;
@end
@implementation FTURLSessionTaskInfo
- (instancetype)initWithTask:(NSURLSessionDataTask *)task delegate:(id<NSURLSessionDataDelegate>)delegate modes:(NSArray *)modes{
    assert(task != nil);
    assert(delegate != nil);
    assert(modes != nil);
    self = [super init];
    if (self != nil) {
        self->_task = task;
        self->_delegate = delegate;
        self->_thread = [NSThread currentThread];
        self->_modes = [modes copy];
    }
    return self;
}

- (void)performBlock:(dispatch_block_t)block{
    assert(self.delegate != nil);
    assert(self.thread != nil);
    [self performSelector:@selector(performBlockOnClientThread:) onThread:self.thread withObject:[block copy] waitUntilDone:NO modes:self.modes];
}

- (void)performBlockOnClientThread:(dispatch_block_t)block{
    assert([NSThread currentThread] == self.thread);
    block();
}

- (void)invalidate{
    self.delegate = nil;
    self.thread = nil;
}

@end
@interface FTSessionConfiguration ()<NSURLSessionDelegate>
@property (nonatomic, strong) NSOperationQueue* sessionDelegateQueue;
@property (nonatomic, strong) NSURLSession *session;
@property (atomic, strong, readonly ) NSMutableDictionary *taskInfoByTaskID;
@property (atomic, assign, readwrite) BOOL shouldIntercept;

@end
@implementation FTSessionConfiguration
static dispatch_once_t onceToken;
static FTSessionConfiguration *staticConfiguration;
+ (FTSessionConfiguration *)defaultConfiguration {
    dispatch_once(&onceToken, ^{
        staticConfiguration=[[FTSessionConfiguration alloc] init];
    });
    return staticConfiguration;
}
- (instancetype)init {
    self = [super init];
    if (self) {
        _shouldIntercept = NO;
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        self->_sessionDelegateQueue                             = [[NSOperationQueue alloc] init];
        self->_sessionDelegateQueue.maxConcurrentOperationCount = 1;
        self->_sessionDelegateQueue.name                        = @"com.session.queue";
        self->_session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:self->_sessionDelegateQueue];
        self->_taskInfoByTaskID = [[NSMutableDictionary alloc]init];
    }
    return self;
}
- (void)startMonitor {
    self.shouldIntercept=YES;
    [NSURLProtocol registerClass:[FTURLProtocol class]];
}
- (void)stopMonitor {
    self.shouldIntercept=NO;
    [NSURLProtocol unregisterClass:[FTURLProtocol class]];
}
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request delegate:(id<NSURLSessionDataDelegate>)delegate modes:(NSArray *)modes{
    NSURLSessionDataTask *task;
    if ([modes count] == 0) {
        modes = @[NSDefaultRunLoopMode];
    }
    task = [self.session dataTaskWithRequest:request];
    FTURLSessionTaskInfo *info = [[FTURLSessionTaskInfo alloc]initWithTask:task delegate:delegate modes:modes];
    @synchronized (self) {
        self.taskInfoByTaskID[@(task.taskIdentifier)] = info;
    }
    
    return task;
}
- (FTURLSessionTaskInfo *)taskInfoForTask:(NSURLSessionTask *)task{
    if(!task){
        return nil;
    }
    FTURLSessionTaskInfo *info;
    @synchronized (self) {
        info = self.taskInfoByTaskID[@(task.taskIdentifier)];
    }
    return info;
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
    FTURLSessionTaskInfo *info = [self taskInfoForTask:dataTask];
    if([info.delegate respondsToSelector:@selector(URLSession:dataTask:didReceiveResponse:completionHandler:)]){
        [info performBlock:^{
            [info.delegate URLSession:session dataTask:dataTask didReceiveResponse:response completionHandler:completionHandler];
        }];
    }else{
        completionHandler(NSURLSessionResponseAllow);
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data{
    FTURLSessionTaskInfo *info = [self taskInfoForTask:dataTask];
    if ([info.delegate respondsToSelector:@selector(URLSession:dataTask:didReceiveData:)]) {
        [info performBlock:^{
            [info.delegate URLSession:session dataTask:dataTask didReceiveData:data];
        }];
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error{
    FTURLSessionTaskInfo *info = [self taskInfoForTask:task];
    @synchronized (self) {
        [self.taskInfoByTaskID removeObjectForKey:@(info.task.taskIdentifier)];
    }
    if ([info.delegate respondsToSelector:@selector(URLSession:task:didCompleteWithError:)]) {
        [info performBlock:^{
            [info.delegate URLSession:session task:task didCompleteWithError:error];
            [info invalidate];
        }];
    }else{
        [info invalidate];
    }
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics  API_AVAILABLE(ios(10.0)){
    FTURLSessionTaskInfo *info = [self taskInfoForTask:task];
    if ([info.delegate respondsToSelector:@selector(URLSession:task:didFinishCollectingMetrics:)]) {
        [info performBlock:^{
            [info.delegate URLSession:session task:task didFinishCollectingMetrics:metrics];
        }];
    }
    
}
- (void)shutDown{
    [self stopMonitor];
    [self.session invalidateAndCancel];
    onceToken = 0;
    staticConfiguration = nil;
}
@end
