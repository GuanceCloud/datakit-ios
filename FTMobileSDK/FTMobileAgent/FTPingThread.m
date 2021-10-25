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
@property (atomic, assign) BOOL isResponse;
@property (nonatomic, strong) dispatch_semaphore_t semaphore;
@property (atomic, strong) NSDate *freezeStartDate;
@property (atomic, copy) NSString *callSymbols;
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
                NSTimeInterval aTimeInterval = [[NSDate date] timeIntervalSinceReferenceDate] - 0.5;
                self.freezeStartDate = [NSDate dateWithTimeIntervalSinceReferenceDate:aTimeInterval];                self.callSymbols = [FTCallStack ft_backtraceOfMainThread];
            }
            dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
        }
    }
}

@end
