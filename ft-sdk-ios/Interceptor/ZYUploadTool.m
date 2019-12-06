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
@interface ZYUploadTool()
@property (nonatomic, strong) NSDictionary *tag;
@property (nonatomic, assign) BOOL isUploading;
@end
@implementation ZYUploadTool

-(void)upload{
    if (!self.isUploading) {
        NSArray *data = [[ZYTrackerEventDBTool sharedManger] getDatas];
        ZYDebug(@"getDatas == %@",data);
        [self flushQueue:data];
    }
}
- (void)flushQueue:(NSArray *)queue{
    self.isUploading = YES;
    NSMutableArray *upDatas = [queue mutableCopy];
    RecordModel *model = [upDatas lastObject];
    long tm = model.tm;
    @try {
        while ([upDatas count]>0){
         NSData *response = [self apiRequestWithData:[upDatas firstObject] andError:nil];
            if (response == nil) {
                self.isUploading = NO;
                RecordModel *model = [upDatas firstObject];
                tm = model.tm-1;
                break;
            }
            [upDatas removeObjectAtIndex:0];
        }
        [[ZYTrackerEventDBTool sharedManger] deleteItemWithTm:tm];
    }
    @catch (NSException *exception) {
           ZYDebug(@"flushQueue exception %@",exception);
    }
}
- (NSData*)apiRequestWithData:(NSString *)requestData andError:(NSError *)error {
    BOOL success = NO;
    int  retry = 0;
    NSData *responseData = nil;
    //请求不成功 重试 请求3次还不成功 结束
    while (!success && retry < 3) {
        NSURL *URL = nil;
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];

    }
    return nil;
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
