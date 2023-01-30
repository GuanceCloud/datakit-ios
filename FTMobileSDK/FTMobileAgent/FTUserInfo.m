//
//  FTUserInfo.m
//  FTMobileAgent
//
//  Created by hulilei on 2022/8/8.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import "FTUserInfo.h"
#import "FTConstants.h"
@interface FTUserInfo()
@property (nonatomic, copy, readwrite) NSString *userId;
@property (nonatomic, copy, readwrite) NSString *name;
@property (nonatomic, copy, readwrite) NSString *email;
@property (nonatomic, strong, readwrite) NSDictionary *extra;
@property (nonatomic, assign, readwrite) BOOL isSignin;
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
            self.isSignin = YES;
        }else{
            NSString *user = [FTUserInfo userId];
            if (user) {
                [self updateUser:user name:nil email:nil extra:nil];
            }else{
                self.userId = [FTUserInfo userSessionId];
                self.isSignin = NO;
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
    self.isSignin = YES;
}
-(void)clearUser{
    [[NSUserDefaults standardUserDefaults] setObject:nil forKey:FT_USER_INFO];
    [[NSUserDefaults standardUserDefaults] synchronize];
    self.userId = [FTUserInfo userSessionId];
    self.name = nil;
    self.extra = nil;
    self.email = nil;
    self.isSignin = NO;
}
//适配 1.3.6 及以下版本
+ (NSString *)userId{
    NSString  *userid =[[NSUserDefaults standardUserDefaults] valueForKey:@"ft_userid"];
    return userid;
}
//userID 用户未设置时的默认值
+ (NSString *)userSessionId{
    NSString  *sessionid =[[NSUserDefaults standardUserDefaults] valueForKey:@"ft_sessionid"];
    if (!sessionid) {
        sessionid = [[NSUUID UUID] UUIDString];
        [[NSUserDefaults standardUserDefaults] setValue:sessionid forKey:@"ft_sessionid"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    return sessionid;
}
@end
