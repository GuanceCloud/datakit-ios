//
//  FTRUMSessionScope.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/5/25.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTRUMSessionScope.h"
#import "FTBaseInfoHander.h"
#import "FTRUMViewScope.h"
static const NSTimeInterval sessionTimeoutDuration = 15 * 60; // 15 minutes
/// Maximum duration of a session. If it gets exceeded, a new session is started.
static const NSTimeInterval sessionMaxDuration = 4 * 60 * 60; // 4 hours
@interface FTRUMSessionScope()<FTRUMScopeProtocol>
@property (nonatomic, strong) NSDate *sessionStartTime;
@property (nonatomic, strong) NSDate *lastInteractionTime;
@property (nonatomic, copy,readwrite) NSString *sessionUUID;
@property (nonatomic, strong) NSMutableArray<FTRUMViewScope*> *viewScope;
@property (nonatomic, weak) UIViewController *currentViewController;
@end
@implementation FTRUMSessionScope
-(instancetype)init{
    self = [super init];
    if (self) {
        self.sessionUUID = [[NSUUID UUID] UUIDString];
        self.assistant = self;
    }
    return  self;
}
- (BOOL)process:(FTRUMModel *)commond {
    if ([self timedOutOrExpired:[NSDate date]]) {
        return NO;
    }
    _lastInteractionTime = [NSDate date];
    
    //如果是打开view
//    if ([commond.tags[@"A"] isEqualToString:@"start"]) {
//        [self startView:commond];
//    }
    
    
    return  NO;
}
-(void)startView:(FTRUMModel *)commond{
    
}
-(BOOL)timedOutOrExpired:(NSDate*)currentTime{
    NSTimeInterval timeElapsedSinceLastInteraction = [currentTime timeIntervalSinceDate:_lastInteractionTime];
    BOOL timedOut = timeElapsedSinceLastInteraction >= sessionTimeoutDuration;

    NSTimeInterval sessionDuration = [currentTime  timeIntervalSinceDate:_sessionStartTime];
    BOOL expired = sessionDuration >= sessionMaxDuration;

    return timedOut || expired;
}
@end


