//
//  FTExtensionManager.m
//  FTMobileExtension
//
//  Created by 胡蕾蕾 on 2020/11/13.
//  Copyright © 2020 hll. All rights reserved.
//

#import "FTExtensionManager.h"
#import "FTExtensionDataManager.h"
#import "FTUncaughtExceptionHandler.h"
#import "FTLog.h"
static const NSTimeInterval sessionTimeoutDuration = 15 * 60; // 15 minutes
static const NSTimeInterval sessionMaxDuration = 4 * 60 * 60; // 4 hours
@interface FTExtensionManager ()<FTErrorDataDelegate>
@property (nonatomic, copy) NSString *groupIdentifer;
@property (nonatomic, strong) NSDate *lastInteractionTime;
@property (nonatomic, strong) NSDate *sessionStartTime;
@property (nonatomic, copy) NSString *sessionId;
@end
@implementation FTExtensionManager
static FTExtensionManager *sharedInstance = nil;
+ (instancetype)sharedInstance{
    NSAssert(sharedInstance, @"请先使用 startWithApplicationGroupIdentifier: 初始化");
    return sharedInstance;
}
+ (void)startWithApplicationGroupIdentifier:(NSString *)groupIdentifer{
    NSAssert((groupIdentifer.length!=0 ), @"请填写Group Identifier");
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[FTExtensionManager alloc]initWithGroupIdentifier:groupIdentifer];
    });

}
-(instancetype)initWithGroupIdentifier:(NSString *)identifier{
    self = [super init];
    if (self) {
        [[FTUncaughtExceptionHandler sharedHandler] addftSDKInstance:self];
        _sessionStartTime = [NSDate date];
        _sessionId = [[NSUUID UUID] UUIDString];
    }
    return self;
}
-(void)addErrorWithType:(NSString *)type message:(NSString *)message stack:(NSString *)stack{
    NSDate *currentDate = [NSDate date];
    if([self timedOutOrExpired:currentDate]){
        [self refreshWithDate:currentDate];
    }
    NSDictionary *field = @{ @"error_message":message,
                             @"error_stack":stack,
    };
    NSDictionary *tags = @{
        @"error_type":type,
        @"error_source":@"logger",
    };
    [[FTExtensionDataManager sharedInstance] writeEventType:@"error" tags:tags fields:field groupIdentifier:self.groupIdentifer];
}
-(void)refreshWithDate:(NSDate *)date{
    self.sessionId = [NSUUID UUID].UUIDString;
    self.sessionStartTime = date;
    self.lastInteractionTime = date;
}
-(BOOL)timedOutOrExpired:(NSDate*)currentTime{
    NSTimeInterval timeElapsedSinceLastInteraction = [currentTime timeIntervalSinceDate:_lastInteractionTime];
    BOOL timedOut = timeElapsedSinceLastInteraction >= sessionTimeoutDuration;
    NSTimeInterval sessionDuration = [currentTime  timeIntervalSinceDate:_sessionStartTime];
    BOOL expired = sessionDuration >= sessionMaxDuration;
    return timedOut || expired;
}
+ (void)enableLog:(BOOL)enable{
    [FTLog enableLog:enable];
}
@end
