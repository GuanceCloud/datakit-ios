//
//  FTPingThread.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/1/26.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTPingThread.h"
#import "FTCallStack.h"

@interface FTPingThread ()
@property (nonatomic, strong) NSLock *lock;
@property (nonatomic, assign) BOOL isResponse;
@property (nonatomic, strong) dispatch_semaphore_t semaphore;
@end
@implementation FTPingThread

- (void)main {
    [self pingMainThread];
}
-(dispatch_semaphore_t)semaphore{
    if (!_semaphore) {
        _semaphore = dispatch_semaphore_create(0);
    }
    return _semaphore;
}
-(NSLock *)lock{
    if (!_lock) {
        _lock = [[NSLock alloc]init];
    }
    return _lock;
}
-(BOOL)getIsResponse{
    [self.lock lock];
    BOOL result = _isResponse;
    [self.lock unlock];
    return result;
}
-(void)setIsResponse:(BOOL)isResponse{
    [self.lock lock];
    _isResponse = isResponse;
    [self.lock unlock];
}

- (void)pingMainThread {
    while (!self.cancelled) {
        @autoreleasepool {
            self.isResponse = NO;
            dispatch_async(dispatch_get_main_queue(), ^{
                self.isResponse = YES;
                dispatch_semaphore_signal(self.semaphore);
            });
            [NSThread sleepForTimeInterval: 0.5];
            if (self.isResponse == NO){
                NSString *callSymbols = [FTCallStack ft_backtraceOfMainThread];
                if (self.block) {
                    self.block(callSymbols);
                }
            }
            dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
        }
    }
}

@end
