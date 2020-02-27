//
//  TestAccount.m
//  ft-sdk-iosTest
//
//  Created by 胡蕾蕾 on 2020/2/27.
//  Copyright © 2020 hll. All rights reserved.
//

#import "TestAccount.h"

//请配置测试 DataFlux账号
NSString * const FTTestAccount  = @"TEST_ACCOUNT";
NSString * const FTTestPassword  = @"TEST_PWD";

//配置测试 SDK config
NSString * const ACCESS_KEY_ID  = @"Your App akId";
NSString * const ACCESS_KEY_SECRET  = @"Your App akSecret";
NSString * const ACCESS_SERVER_URL  = @"Your App metricsUrl";
@implementation TestAccount
-(instancetype)init{
    if (self = [super init]) {
        self.accessKeyID = ACCESS_KEY_ID;
        self.accessKeySecret = ACCESS_KEY_SECRET;
        self.accessServerUrl = ACCESS_SERVER_URL;
        self.ftTestPassword = FTTestPassword;
        self.ftTestAccount = FTTestAccount;
        [self getProperty];
    }
    return self;
}
- (void)getProperty{
    NSString *path = [[NSBundle mainBundle] pathForResource:@"testAccount" ofType:@"json"];
    // 将文件数据化
    NSData *data = [[NSData alloc] initWithContentsOfFile:path];
    NSError *errors;
    NSMutableDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&errors];
    if (dict.allKeys.count>0) {
        if ([dict.allKeys containsObject:@"ftTestAccount"]) {
            self.ftTestAccount = dict[@"ftTestAccount"];
        }
        if ([dict.allKeys containsObject:@"ftTestPassword"]) {
            self.ftTestPassword = dict[@"ftTestPassword"];
        }
        if ([dict.allKeys containsObject:@"accessKeyID"]) {
            self.accessKeyID = dict[@"accessKeyID"];
        }
        if ([dict.allKeys containsObject:@"accessKeySecret"]) {
            self.accessKeySecret = dict[@"accessKeySecret"];
        }
        if ([dict.allKeys containsObject:@"accessServerUrl"]) {
            self.accessServerUrl = dict[@"accessServerUrl"];
        }
        
    }
}
@end
