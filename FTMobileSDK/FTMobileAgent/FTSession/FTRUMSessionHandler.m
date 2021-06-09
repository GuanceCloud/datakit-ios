//
//  FTRUMsessionHandler.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/5/26.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTRUMSessionHandler.h"
#import <UIKit/UIKit.h>
#import "FTRUMViewHandler.h"
static const NSTimeInterval sessionTimeoutDuration = 15 * 60; // 15 minutes
static const NSTimeInterval sessionMaxDuration = 4 * 60 * 60; // 4 hours
@interface FTRUMSessionHandler()<FTRUMSessionProtocol>
@property (nonatomic, strong) NSDate *sessionStartTime;
@property (nonatomic, strong) NSDate *lastInteractionTime;
@property (nonatomic, strong) NSMutableArray<FTRUMHandler*> *viewHandlers;
@property (nonatomic, strong) FTRUMSessionModel *sessionModel;
@end
@implementation FTRUMSessionHandler
-(instancetype)initWithModel:(FTRUMDataModel *)model{
    self = [super init];
    if (self) {
        self.assistant = self;
        self.sessionStartTime = model.time;
        self.viewHandlers = [NSMutableArray new];
        self.sessionModel = [[FTRUMSessionModel alloc]initWithSessionID:[NSUUID UUID].UUIDString];
    }
    return  self;
}
-(void)refreshWithDate:(NSDate *)date{
    self.sessionModel.session_id = [NSUUID UUID].UUIDString;
    self.sessionStartTime = date;
    self.lastInteractionTime = date;
}
- (BOOL)process:(FTRUMDataModel *)model {
    if ([self timedOutOrExpired:[NSDate date]]) {
        return NO;
    }
    _lastInteractionTime = [NSDate date];
    //数据与session绑定
    model.baseSessionData = self.sessionModel;
  
    switch (model.type) {
        case FTRUMDataViewStart:
            [self startView:model];
            break;
        case FTRUMDataLaunchCold:
            if (self.viewHandlers.count == 0) {
                [self startView:model];
            }
            break;
        case FTRUMDataError:
            if (self.viewHandlers.count == 0) {
                [self startView:model];
            }
            break;
        default:
            break;
    }
    self.viewHandlers = [self.assistant manageChildHandlers:self.viewHandlers byPropagatingData:model];
    return  YES;
}
-(void)startView:(FTRUMDataModel *)model{
    
    FTRUMViewHandler *viewHandler = [[FTRUMViewHandler alloc]initWithModel:model];
    [self.viewHandlers addObject:viewHandler];
}
-(BOOL)timedOutOrExpired:(NSDate*)currentTime{
    NSTimeInterval timeElapsedSinceLastInteraction = [currentTime timeIntervalSinceDate:_lastInteractionTime];
    BOOL timedOut = timeElapsedSinceLastInteraction >= sessionTimeoutDuration;

    NSTimeInterval sessionDuration = [currentTime  timeIntervalSinceDate:_sessionStartTime];
    BOOL expired = sessionDuration >= sessionMaxDuration;

    return timedOut || expired;
}
@end
