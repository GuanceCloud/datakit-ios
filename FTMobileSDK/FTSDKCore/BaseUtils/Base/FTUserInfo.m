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
@implementation FTUserInfo

-(instancetype)init{
    self = [super init];
    if (self) {
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
-(NSDictionary *)updateUser:(NSString *)Id name:(NSString *)name email:(NSString *)email extra:(NSDictionary *)extra{
    NSMutableDictionary *dict = [NSMutableDictionary new];
    [dict setValue:Id forKey:FT_USER_ID];
    [dict setValue:name forKey:FT_USER_NAME];
    [dict setValue:extra forKey:FT_USER_EXTRA];
    [dict setValue:email forKey:FT_USER_EMAIL];
    [[NSUserDefaults standardUserDefaults] setObject:dict forKey:kFTUserInfo];
    [[NSUserDefaults standardUserDefaults] synchronize];
    self.userId = Id;
    self.name = name;
    self.extra = extra;
    self.email = email;
    self.isSignIn = YES;
    return [self userInfoDict];
}
-(NSDictionary *)clearUser{
    [[NSUserDefaults standardUserDefaults] setObject:nil forKey:kFTUserInfo];
    NSString *userId = [FTUserInfo userSessionId];
    self.userId = userId;
    self.name = nil;
    self.extra = nil;
    self.email = nil;
    self.isSignIn = NO;
    return [self userInfoDict];
}
- (NSDictionary *)userInfoDict{
    NSMutableDictionary *dict = [NSMutableDictionary new];
    [dict setValue:self.userId forKey:FT_USER_ID];
    [dict setValue:self.name forKey:FT_USER_NAME];
    [dict setValue:self.email forKey:FT_USER_EMAIL];
    [dict setValue:self.isSignIn ? @"T" : @"F" forKey:FT_IS_SIGNIN];
    if (self.extra) [dict addEntriesFromDictionary:self.extra];
    return [dict copy];
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
@end
