//
//  FTRUMSessionScope.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/5/26.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTRUMSessionScope.h"
#import <UIKit/UIKit.h>
#import "FTRUMViewScope.h"
static const NSTimeInterval sessionTimeoutDuration = 15 * 60; // 15 minutes
/// Maximum duration of a session. If it gets exceeded, a new session is started.
static const NSTimeInterval sessionMaxDuration = 4 * 60 * 60; // 4 hours
@interface FTRUMSessionScope()<FTRUMScopeProtocol>
@property (nonatomic, strong) NSDate *sessionStartTime;
@property (nonatomic, strong) NSDate *lastInteractionTime;
@property (nonatomic, copy,readwrite) NSString *sessionUUID;
@property (nonatomic, strong) NSMutableArray<FTRUMScope*> *viewScopes;
@property (nonatomic, weak) UIViewController *currentViewController;
@property (nonatomic, strong) FTRUMSessionModel *sessionModel;
@end
@implementation FTRUMSessionScope
-(instancetype)initWithModel:(FTRUMCommand *)model{
    self = [super init];
    if (self) {
        self.sessionUUID = [[NSUUID UUID] UUIDString];
        self.assistant = self;
        self.sessionStartTime = model.time;
        self.viewScopes = [NSMutableArray new];
        self.sessionModel = [[FTRUMSessionModel alloc]initWithSessionID:self.sessionUUID];
    }
    return  self;
}
-(void)refreshWithDate:(NSDate *)date{
    self.sessionStartTime = date;
    self.sessionUUID = [[NSUUID UUID] UUIDString];
}
- (BOOL)process:(FTRUMCommand *)commond {
    if ([self timedOutOrExpired:[NSDate date]]) {
        return NO;
    }
    _lastInteractionTime = [NSDate date];
    //数据与session绑定
    commond.baseSessionData = self.sessionModel;
  
    switch (commond.type) {
        case FTRUMDataViewStart:
            [self startView:commond];
            break;
        case FTRUMDataLaunchCold:
            if (!self.currentViewController) {
                [self startView:commond];
            }
            break;
        
        default:
            break;
    }
    self.viewScopes = [self.assistant manageChildScopes:self.viewScopes byPropagatingCommand:commond];
    return  YES;
}
-(void)startView:(FTRUMCommand *)commond{
    
    FTRUMViewScope *viewScope = [[FTRUMViewScope alloc]initWithModel:commond];
    [self.viewScopes addObject:viewScope];
}
-(BOOL)timedOutOrExpired:(NSDate*)currentTime{
    NSTimeInterval timeElapsedSinceLastInteraction = [currentTime timeIntervalSinceDate:_lastInteractionTime];
    BOOL timedOut = timeElapsedSinceLastInteraction >= sessionTimeoutDuration;

    NSTimeInterval sessionDuration = [currentTime  timeIntervalSinceDate:_sessionStartTime];
    BOOL expired = sessionDuration >= sessionMaxDuration;

    return timedOut || expired;
}
@end
