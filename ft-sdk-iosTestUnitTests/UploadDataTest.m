//
//  UploadDataTest.m
//  ft-sdk-iosTestUnitTests
//
//  Created by 胡蕾蕾 on 2020/8/26.
//  Copyright © 2020 hll. All rights reserved.
//

#import "UploadDataTest.h"

@implementation UploadDataTest
- (NSString *)testObject{
    NSDictionary *param = @{@"queries":@[@{@"index":@"object",
                                           @"body":@{
                                                   @"query":@{
                                                           @"bool":@{
                                                                   @"filter":@[@{@"term":@{
                                                                                         @"__tags.__class.keyword": @"iOSTest"
                                                                   }}]
                                                                   
                                                           }},
                                                   @"sort":@[@{@"__esCreateTime":@{
                                                                       @"order": @"desc"
                                                   }}],
                                                   @"from": @0,
                                                   @"size": @1,
                                           },
    }
    ]};
    NSDictionary *dict = [self getUploadResultWithUrl:@"http://testing.api-ft2x.cloudcare.cn:10531/api/v1/elasticsearch/msearch" params:param];
    NSString *name = nil;
    if([[dict valueForKey:@"code"] intValue] == 200){
        NSDictionary *content = dict[@"content"];
        NSArray *responses = content[@"responses"];
        NSDictionary *hitsDict = [responses firstObject][@"hits"];
        NSArray *hitsArray = hitsDict[@"hits"];
        NSDictionary *_source = [hitsArray firstObject][@"_source"];
        name = _source[@"__name"];
    }
    return name;
}
- (NSString *)testLogging{
    return nil;
}
- (NSString *)testTrack{
    return nil;
}
- (NSString *)tesrTrace{
    return nil;
}
-(NSString *)login{
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *account =[processInfo environment][@"TFTTestAccount"];
    NSString *password = [processInfo environment][@"TFTTestPassword"];
    if (account.length>0 && password.length>0) {
    }else{
        return @"";
    }
    NSURL *url = [NSURL URLWithString:@"http://testing.api-ft2x.cloudcare.cn:10531/api/v1/auth-token/login"];
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:url];
    NSMutableURLRequest *mutableRequest = [request mutableCopy];    //拷贝request
    mutableRequest.HTTPMethod = @"POST";
    //添加header
    [mutableRequest addValue:@"application/json;charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
    
    //设置请求参数
    [mutableRequest setValue:@"zh-CN" forHTTPHeaderField:@"Accept-Language"];
    NSDictionary *param = @{
        @"username": account,
        @"password": password,
        @"workspaceUUID": [NSString stringWithFormat:@"wksp_%@",[[NSUUID UUID] UUIDString]],
    };
    NSData* data = [NSJSONSerialization dataWithJSONObject:param options:NSJSONWritingPrettyPrinted error:nil];
    NSString *bodyData = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    [mutableRequest setHTTPBody:[NSData dataWithBytes:[bodyData UTF8String] length:strlen([bodyData UTF8String])]];
    
    
    request = [mutableRequest copy];
    __block NSString *token = @"";
    
    //设置请求session
    NSURLSession *session = [NSURLSession sharedSession];
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_enter(group);
    
    //设置网络请求的返回接收器
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            if (!error) {
                NSError *errors;
                NSMutableDictionary *responseObject = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&errors];
                
                if (!errors){
                    NSDictionary *content = [responseObject valueForKey:@"content"];
                    token = [content valueForKey:@"token"];
                }
            }
            dispatch_group_leave(group);
        
    }];
    //开始请求
    [dataTask resume];
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    
    return token;
}
- (NSDictionary *)getUploadResultWithUrl:(NSString *)url params:(NSDictionary *)param{
    NSString *token = [self login];
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:url]];
    //设置请求地址
    //添加header
    NSMutableURLRequest *mutableRequest = [request mutableCopy];    //拷贝request
    mutableRequest.HTTPMethod = @"POST";
    //添加header
    [mutableRequest addValue:@"application/json;charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
    
    //设置请求参数
    [mutableRequest setValue:token forHTTPHeaderField:@"X-FT-Auth-Token"];
    [mutableRequest setValue:@"zh-CN" forHTTPHeaderField:@"Accept-Language"];
    NSData* data = [NSJSONSerialization dataWithJSONObject:param options:NSJSONWritingPrettyPrinted error:nil];
    NSString *bodyData = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    [mutableRequest setHTTPBody:[NSData dataWithBytes:[bodyData UTF8String] length:strlen([bodyData UTF8String])]];
    request = [mutableRequest copy];        //拷贝回去
    __block NSMutableDictionary *responseObject;
    //设置请求session
    NSURLSession *session = [NSURLSession sharedSession];
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_enter(group);
    
    //设置网络请求的返回接收器
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            if (!error){
                NSError *errors;
                responseObject = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&errors];
            }
            dispatch_group_leave(group);        
    }];
    //开始请求
    [dataTask resume];
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    
    return responseObject;
}
@end
