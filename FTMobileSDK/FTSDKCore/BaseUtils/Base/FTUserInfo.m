//
//  FTUserInfo.m
//  FTMobileAgent
//
//  Created by hulilei on 2022/8/8.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import "FTUserInfo.h"
#import "FTConstants.h"
#import "FTBaseInfoHandler.h"
#import <os/lock.h>
NSString * const kFTUserInfo = @"FT_USER_INFO";
@interface FTUserInfo()
@property (nonatomic, copy, readwrite) NSString *userId;
@property (nonatomic, copy, readwrite) NSString *name;
@property (nonatomic, copy, readwrite) NSString *email;
@property (nonatomic, copy, readwrite) NSDictionary *extra;
@property (nonatomic, assign, readwrite) BOOL isSignIn;
@end
@implementation FTUserInfo{
    os_unfair_lock _lock; 
}
-(instancetype)init{
    self = [super init];
    if (self) {
        _lock = OS_UNFAIR_LOCK_INIT;
        NSDictionary *dict = [[NSUserDefaults standardUserDefaults] dictionaryForKey:kFTUserInfo];
        if (dict) {
            _userId = [dict valueForKey:FT_USER_ID];
            _name = [dict valueForKey:FT_USER_NAME];
            _extra = [dict valueForKey:FT_USER_EXTRA];
            _email = [dict valueForKey:FT_USER_EMAIL];
            _isSignIn = YES;
        }else{
            NSString *user = [FTUserInfo userId];
            if (user) {
                [self updateUser:user name:nil email:nil extra:nil];
            }else{
                _userId = [FTUserInfo userSessionId];
                _isSignIn = NO;
            }
        }
    }
    return self;
}
-(void)updateUser:(NSString *)Id name:(NSString *)name email:(NSString *)email extra:(NSDictionary *)extra{
    NSMutableDictionary *dict = [NSMutableDictionary new];
    [dict setValue:Id forKey:FT_USER_ID];
    [dict setValue:name forKey:FT_USER_NAME];
    [dict setValue:extra forKey:FT_USER_EXTRA];
    [dict setValue:email forKey:FT_USER_EMAIL];
    [[NSUserDefaults standardUserDefaults] setObject:dict forKey:kFTUserInfo];
    [[NSUserDefaults standardUserDefaults] synchronize];
    os_unfair_lock_lock(&_lock);
    self.userId = Id;
    self.name = name;
    self.extra = extra;
    self.email = email;
    self.isSignIn = YES;
    os_unfair_lock_unlock(&_lock);
}
-(void)clearUser{
    [[NSUserDefaults standardUserDefaults] setObject:nil forKey:kFTUserInfo];
    [[NSUserDefaults standardUserDefaults] synchronize];
    NSString *userId = [FTUserInfo userSessionId];
    os_unfair_lock_lock(&_lock);
    self.userId = userId;
    self.name = nil;
    self.extra = nil;
    self.email = nil;
    self.isSignIn = NO;
    os_unfair_lock_unlock(&_lock);
}
//Compatible with version 1.3.6 and below
+ (NSString *)userId{
    NSString  *userid =[[NSUserDefaults standardUserDefaults] valueForKey:@"ft_userid"];
    return userid;
}
//Default value when userID is not set by user
+ (NSString *)userSessionId{
    NSString  *sessionId =[[NSUserDefaults standardUserDefaults] valueForKey:@"ft_sessionid"];
    if (!sessionId) {
        sessionId = [FTBaseInfoHandler randomUUID];
        [[NSUserDefaults standardUserDefaults] setValue:sessionId forKey:@"ft_sessionid"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    return sessionId;
}
-(id)copyWithZone:(NSZone *)zone{
    FTUserInfo *copy = [[[self class] allocWithZone:zone] init];
    os_unfair_lock_lock(&_lock);
    copy.userId = [self.userId copy];
    copy.email = [self.email copy];
    copy.extra = [self.extra copy];
    copy.name = [self.name copy];
    copy.isSignIn = self.isSignIn;
    os_unfair_lock_unlock(&_lock);
    return copy;
}
@end
