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
@property (nonatomic, strong) NSDate *freezeStartDate;
@property (nonatomic, copy) NSString *callSymbols;
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
-(NSDate *)getFreezeStartDate{
    [self.lock lock];
    NSDate *freezeStartDate = _freezeStartDate;
    [self.lock unlock];
    return freezeStartDate;
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
-(void)setFreezeStartDate:(NSDate *)freezeStartDate{
    [self.lock lock];
    _freezeStartDate = freezeStartDate;
    [self.lock unlock];
}
-(void)setCallSymbols:(NSString *)callSymbols{
    [self.lock lock];
    _callSymbols = callSymbols;
    [self.lock unlock];
}
-(NSString *)getCallSymbols{
    [self.lock lock];
    NSString *callSymbols = _callSymbols;
    [self.lock unlock];
    return  callSymbols;
}
- (void)pingMainThread {
    while (!self.cancelled) {
        @autoreleasepool {
            self.isResponse = NO;
            dispatch_async(dispatch_get_main_queue(), ^{
                self.isResponse = YES;
                if (self.freezeStartDate) {
                    self.block(self.callSymbols,self.freezeStartDate,[NSDate date]);
                    self.freezeStartDate = nil;
                }
                dispatch_semaphore_signal(self.semaphore);
            });
            [NSThread sleepForTimeInterval: 0.5];
            if (self.isResponse == NO){
                self.freezeStartDate = [NSDate date];
                self.callSymbols = [FTCallStack ft_backtraceOfMainThread];
            }
            dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
        }
    }
}

@end
