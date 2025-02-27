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
@interface FTUserInfo()
@property (nonatomic, copy, readwrite) NSString *userId;
@property (nonatomic, copy, readwrite) NSString *name;
@property (nonatomic, copy, readwrite) NSString *email;
@property (nonatomic, strong, readwrite) NSDictionary *extra;
@property (nonatomic, assign, readwrite) BOOL isSignIn;
@end
@implementation FTUserInfo
-(instancetype)init{
    self = [super init];
    if (self) {
        NSDictionary *dict = [[NSUserDefaults standardUserDefaults] dictionaryForKey:FT_USER_INFO];
        if (dict) {
            self.userId = [dict valueForKey:FT_USER_ID];
            self.name = [dict valueForKey:FT_USER_NAME];
            self.extra = [dict valueForKey:FT_USER_EXTRA];
            self.email = [dict valueForKey:FT_USER_EMAIL];
            self.isSignIn = YES;
        }else{
            NSString *user = [FTUserInfo userId];
            if (user) {
                [self updateUser:user name:nil email:nil extra:nil];
            }else{
                self.userId = [FTUserInfo userSessionId];
                self.isSignIn = NO;
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
    [[NSUserDefaults standardUserDefaults] setObject:dict forKey:FT_USER_INFO];
    [[NSUserDefaults standardUserDefaults] synchronize];
    self.userId = Id;
    self.name = name;
    self.extra = extra;
    self.email = email;
    self.isSignIn = YES;
}
-(void)clearUser{
    [[NSUserDefaults standardUserDefaults] setObject:nil forKey:FT_USER_INFO];
    [[NSUserDefaults standardUserDefaults] synchronize];
    self.userId = [FTUserInfo userSessionId];
    self.name = nil;
    self.extra = nil;
    self.email = nil;
    self.isSignIn = NO;
}
//适配 1.3.6 及以下版本
+ (NSString *)userId{
    NSString  *userid =[[NSUserDefaults standardUserDefaults] valueForKey:@"ft_userid"];
    return userid;
}
//userID 用户未设置时的默认值
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
    copy.userId = self.userId;
    copy.email = self.email;
    copy.extra = self.extra;
    copy.name = self.name;
    copy.isSignIn = self.isSignIn;
    return copy;
}
@end
