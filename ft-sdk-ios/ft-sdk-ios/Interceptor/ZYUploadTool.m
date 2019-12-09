//
//  ZYUploadTool.m
//  ft-sdk-ios
//
//  Created by 胡蕾蕾 on 2019/12/3.
//  Copyright © 2019 hll. All rights reserved.
//

#import "ZYUploadTool.h"
#import <UIKit/UIKit.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>
#import "ZYBaseInfoHander.h"
#import "ZYTrackerEventDBTool.h"
#import "ZYLog.h"
#import "RecordModel.h"
#import "ZYConfig.h"
@interface ZYUploadTool()
@property (nonatomic, strong) NSDictionary *tag;
@property (nonatomic, assign) BOOL isUploading;
@end
@implementation ZYUploadTool

-(void)upload{
    return; //逻辑不完整
    if (!self.isUploading) {
        //当前数据库所有数据
        NSArray *data = [[ZYTrackerEventDBTool sharedManger] getDatas];
        ZYDebug(@"getDatas == %@",data);
        self.isUploading = YES;
        [self flushQueue:data];
    }
}
- (void)flushQueue:(NSArray *)queue{
    NSMutableArray *upDatas = [queue mutableCopy];
    RecordModel *model = [upDatas lastObject];
    long tm = model.tm-1;
    @try {
        while ([upDatas count]>0){
         NSUInteger sendBatchSize = ([upDatas count] > 10) ? 10 : [queue count];
         NSArray *events = [queue subarrayWithRange:NSMakeRange(0, sendBatchSize)];
         RecordModel *model = [events lastObject];
         BOOL scuess = [self apiRequestWithEventsAry:events andError:nil];
            if (scuess) {//请求失败
                ZYDebug(@"上传事件失败");
                break;
            }
                ZYDebug(@"上传事件成功");
                tm = model.tm;
                [upDatas removeObjectsInArray:events];
        }
        [[ZYTrackerEventDBTool sharedManger] deleteItemWithTm:tm];
        self.isUploading = NO;
    }
    @catch (NSException *exception) {
         ZYDebug(@"flushQueue exception %@",exception);
    }
}
- (BOOL)apiRequestWithEventsAry:(NSArray *)events andError:(NSError *)error {
    
    if (self.config.enableRequestSigning) {
        NSString *authorization = [NSString stringWithFormat:@"DWAY %@:%@",self.config.akId,self.config.akSecret];
    }
    __block BOOL success = NO;
    __block int  retry = 0;
    NSString *requestData;
    //请求不成功 重试 请求3次还不成功 结束
    while (!success && retry < 3) {
            NSURL *url = nil;
            //设置请求地址
            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
            //设置请求方式
            request.HTTPMethod = @"POST";
            [request setValue:@"text/plain" forHTTPHeaderField:@"Content-Type"];
            //设置请求参数
            request.HTTPBody = [requestData dataUsingEncoding:NSUTF8StringEncoding];
          //关于parameters是NSDictionary拼接后的NSString.关于拼接看后面拼接方法说明
        
            //设置请求session
            NSURLSession *session = [NSURLSession sharedSession];
            
            //设置网络请求的返回接收器
            NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (error) {
                        retry++;
                    }else{
                        NSError *errors;
                        NSMutableDictionary *responseObject = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&errors];
                        if (errors){
                            retry++;
                        }else {
                            ZYDebug(@"%@responseObject = %@",responseObject);
                            success = YES;
                        }
                    }
                });
            }];
        //开始请求
            [dataTask resume];
    }
    return success;
}
// 更新网络指示器
- (void)updateNetworkActivityIndicator:(BOOL)on {
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIApplication sharedApplication].networkActivityIndicatorVisible = on;
    });
}

- (NSDictionary *)getBasicData{
    if (_tag != nil) {
        return _tag;
    }
    CFUUIDRef puuid = CFUUIDCreate ( nil ) ;
    CFStringRef uuidString = CFUUIDCreateString ( nil , puuid ) ;
    NSString* uuid = (NSString*)CFBridgingRelease(CFStringCreateCopy(NULL, uuidString));
    NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
    CFShow((__bridge CFTypeRef)(infoDictionary));
    NSString *app_Name = [infoDictionary objectForKey:@"CFBundleDisplayName"];
    NSString *identifier = [infoDictionary objectForKey:@"CFBundleIdentifier"];
    NSString *app_Version = [infoDictionary objectForKey:@"CFBundleShortVersionString"];
    
   
    NSString *preferredLanguage = [[[NSBundle mainBundle] preferredLocalizations] firstObject];
    NSString *version = [UIDevice currentDevice].systemVersion;


    NSDictionary *tag = @{@"device_uuid":uuid,
                          @"application_identifier":identifier,
                          @"application_name":app_Name,
                          @"sdk_version":app_Version,
                          @"imei":@"",
                          @"os":@"iOS",
                          @"os_version":version,
                          @"locale":preferredLanguage,
                          @"device_band":@"",
                          @"device_model":[ZYBaseInfoHander getDeviceType],
                          @"display":[ZYBaseInfoHander resolution],
                          @"carrier":[ZYBaseInfoHander getTelephonyInfo],
    };
    _tag = tag;
    return _tag;
}

@end
