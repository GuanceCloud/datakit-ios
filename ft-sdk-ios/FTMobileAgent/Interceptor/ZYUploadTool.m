//
//  ZYUploadTool.m
//  FTMobileAgent
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
#import "FTMobileConfig.h"
#import "FTLocationManager.h"
#import "FTNetworkInfo.h"
#import "FTNetMonitorFlow.h"
@interface ZYUploadTool()
@property (nonatomic, copy) NSString *tag;
@property (nonatomic, assign) BOOL isUploading;
@property (nonatomic, strong) FTMobileConfig *config;
@property (nonatomic, strong) FTLocationManager *manger;
@property (nonatomic, strong) FTNetMonitorFlow *netFlow;
@property (nonatomic, strong) dispatch_queue_t timerQueue;

@end
@implementation ZYUploadTool
-(instancetype)initWithConfig:(FTMobileConfig *)config{
     self = [super init];
       if (self) {
           self.config = config;
           if(self.config.monitorInfoType & FTMonitorInfoTypeLocation || self.config.monitorInfoType & FTMonitorInfoTypeAll){
               self.manger = [[FTLocationManager alloc]init];
               __weak typeof(self) weakSelf = self;
                self.manger.updateLocationBlock = ^(NSString * _Nonnull location, NSError * _Nonnull error) {
                [weakSelf addLocationInfo:location];
                };
            [self.manger startUpdatingLocation];
               
           }
           if (self.config.monitorInfoType & FTMonitorInfoTypeNetwork || self.config.monitorInfoType & FTMonitorInfoTypeAll) {
               NSString *label = [NSString stringWithFormat:@"io.timer.%p", self];
               self.timerQueue = dispatch_queue_create([label UTF8String], DISPATCH_QUEUE_SERIAL);
               self.netFlow = [FTNetMonitorFlow new];
              
                [self.netFlow startMonitor];
             
           }
       }
       return self;
}

-(void)upload{
    if (!self.isUploading) {
        //当前数据库所有数据
        self.isUploading = YES;
        [self flushQueue];
    }
}
- (void)flushQueue{
   
    @try {
        while ([[ZYTrackerEventDBTool sharedManger] getDatasCount]>0){
            ZYDebug(@"DB DATAS COUNT = %ld",[[ZYTrackerEventDBTool sharedManger] getDatasCount]);
         NSArray *updata = [[ZYTrackerEventDBTool sharedManger] getFirstTenData];
            if(updata.count == 0){
                break;
            }
         RecordModel *model = [updata lastObject];
         BOOL scuess = [self apiRequestWithEventsAry:updata andError:nil];
            if (!scuess) {//请求失败
                ZYDebug(@"上传事件失败");
                break;
            }
                ZYDebug(@"上传事件成功");
            BOOL delect = [[ZYTrackerEventDBTool sharedManger] deleteItemWithTm:model.tm];
            ZYDebug(@"delect == %d",delect);
        }
        self.isUploading = NO;
    }
    @catch (NSException *exception) {
         ZYDebug(@"flushQueue exception %@",exception);
    }
}
- (BOOL)apiRequestWithEventsAry:(NSArray *)events andError:(NSError *)error {
    __block BOOL success =NO;
    __block int  retry = 0;
    NSString *requestData = [self getRequestDataWithEventArray:events];
   
        NSString *date =[ZYBaseInfoHander currentGMT];
        NSURL *url = [NSURL URLWithString:self.config.metricsUrl];
        NSURLRequest *request = [[NSURLRequest alloc] initWithURL:url];
            //设置请求地址
        //添加header
        NSMutableURLRequest *mutableRequest = [request mutableCopy];    //拷贝request
        mutableRequest.HTTPMethod = @"POST";
         //添加header
        [mutableRequest addValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
        [mutableRequest addValue:@"text/plain" forHTTPHeaderField:@"Content-Type"];
        [mutableRequest addValue:@"charset=utf-8" forHTTPHeaderField:@"Content-Type"];

            //设置请求参数
        [mutableRequest setValue:[ZYBaseInfoHander defaultUUID] forHTTPHeaderField:@"X-Datakit-UUID"];
        [mutableRequest setValue:date forHTTPHeaderField:@"Date"];
        [mutableRequest setValue:@"ft_mobile_sdk_ios" forHTTPHeaderField:@"User-Agent"];
        [mutableRequest setValue:@"zh-CN" forHTTPHeaderField:@"Accept-Language"];
        mutableRequest.HTTPBody = [requestData dataUsingEncoding:NSUTF8StringEncoding];
        ZYDebug(@"requestData = %@",requestData);
        if (self.config.enableRequestSigning) {
            NSString *authorization = [NSString stringWithFormat:@"DWAY %@:%@",self.config.akId,[ZYBaseInfoHander getSSOSignWithAkSecret:self.config.akSecret datetime:date data:requestData]];
            [mutableRequest addValue:authorization forHTTPHeaderField:@"Authorization"];
        }
        request = [mutableRequest copy];        //拷贝回去
        
 
            //设置请求session
            NSURLSession *session = [NSURLSession sharedSession];
            dispatch_group_t group = dispatch_group_create();
            dispatch_group_enter(group);

            //设置网络请求的返回接收器
            NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (error) {
                        ZYDebug(@"response error = %@",error);
                        retry++;
                    }else{
                        NSError *errors;
                        NSMutableDictionary *responseObject = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&errors];
                        if (errors){
                            ZYDebug(@"response error = %@",error);
                            retry++;
                        }else {
                            ZYDebug(@"responseObject = %@",responseObject);
                            success = YES;
                        }
                    }
                     dispatch_group_leave(group);
                });
                   
            }];
        //开始请求
            [dataTask resume];
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);

    return success;
}


- (NSString *)getRequestDataWithEventArray:(NSArray *)events{
    __block NSMutableString *requestDatas = [NSMutableString new];
    NSString *basicData = [self getBasicData];
    [events enumerateObjectsUsingBlock:^(RecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *item = [ZYBaseInfoHander dictionaryWithJsonString:obj.data];
        NSDictionary *userData = [ZYBaseInfoHander dictionaryWithJsonString:obj.userdata];
       __block NSString *event = @" ";
        NSDictionary *opdata = item[@"opdata"];
        NSString *field;
        __block NSString *appendTag = @"";
        NSDictionary *tags;
        if([[item valueForKey:@"op"] isEqualToString:@"cstm"]){
            field = [opdata valueForKey:@"field"];
            NSDictionary *values = opdata[@"values"];
            [values enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
                    event = [event stringByAppendingFormat:@"%@=\"%@\",",key,obj];
            }];
           event = event.length>1? [event substringToIndex:event.length-1]:event;
           tags =opdata[@"tags"];
            
        }else{
            NSString *cpn = [item valueForKey:@"cpn"];
            NSString *rpn = (NSString *)[item valueForKey:@"rpn"];
            field =@"mobile_tracker";
            event = [event stringByAppendingFormat:@"event=\"%@\"",[item valueForKey:@"op"]];
            if(cpn){
               appendTag = [appendTag stringByAppendingFormat:@"current_page_name=%@,",cpn];
            }
            if (rpn && ![rpn isEqualToString:@"null"]) {
                if(rpn.length>0){
               appendTag =[appendTag stringByAppendingFormat:@"root_page_name=%@,",rpn];
                }
            }
            if (opdata) {
                tags = opdata;
            }
        }
        [tags enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
                appendTag = [appendTag stringByAppendingFormat:@"%@=%@,",key,obj];
        }];
        [userData enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            if ([obj isKindOfClass:NSString.class]) {
                appendTag = [appendTag stringByAppendingFormat:@"ud_%@=%@,",key,obj];
            }
            if ([obj isKindOfClass:NSDictionary.class]) {
                [obj enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key2, id  _Nonnull obj2, BOOL * _Nonnull stop) {
                    appendTag = [appendTag stringByAppendingFormat:@"ud_%@=%@,",key2,obj2];
                }];
            }
        }];
        appendTag =appendTag.length>1? [appendTag substringToIndex:appendTag.length-1]:appendTag;

        if (idx==0) {
                [requestDatas appendFormat:@"%@,%@",field,basicData];
        }else{
                [requestDatas appendFormat:@"\n%@,%@",field,basicData];
        }
        appendTag = [appendTag stringByReplacingOccurrencesOfString:@" " withString:@"\\ "];
        [requestDatas appendString:appendTag];
        [requestDatas appendString:event];
        [requestDatas appendFormat:@" %ld",obj.tm*1000];
    
    }];
  
    return requestDatas;
}
- (void)addLocationInfo:(NSString *)location{
    [self basicTags];
    _tag = [_tag stringByAppendingFormat:@"location_city=%@,",location];
   
}
- (NSString *)basicTags{
    if (_tag != nil) {
           return _tag;
       }
       NSString * uuid =[[UIDevice currentDevice] identifierForVendor].UUIDString;
       NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
       CFShow((__bridge CFTypeRef)(infoDictionary));
       NSString *app_Name = [infoDictionary objectForKey:@"CFBundleDisplayName"];
       NSString *identifier = [infoDictionary objectForKey:@"CFBundleIdentifier"];

       NSString *preferredLanguage = [[[NSBundle mainBundle] preferredLocalizations] firstObject];
       NSString *version = [UIDevice currentDevice].systemVersion;
       NSMutableString *tag = [NSMutableString string];

       [tag appendFormat:@"device_uuid=%@,",uuid];
       [tag appendFormat:@"application_identifier=%@,",identifier];
       [tag appendFormat:@"application_name=%@,",app_Name];
       [tag appendFormat:@"sdk_version=%@,",self.config.sdkVersion];
       [tag appendString:@"os=iOS,"];
       [tag appendFormat:@"os_version=%@,",version];
       [tag appendString:@"device_band=APPLE,"];
       [tag appendFormat:@"locale=%@,",preferredLanguage];
       [tag appendFormat:@"device_model=%@,",[ZYBaseInfoHander getDeviceType]];
       [tag appendFormat:@"display=%@,",[ZYBaseInfoHander resolution]];
       [tag appendFormat:@"carrier=%@,",[ZYBaseInfoHander getTelephonyInfo]];
//    if (self.config.monitorInfoType &FTMonitorInfoTypeBattery) {
//        [tag appendFormat:@"battery_total=%@,",[ZYBaseInfoHander getTelephonyInfo]];
//    }
    if (self.config.monitorInfoType & FTMonitorInfoTypeMemory || self.config.monitorInfoType & FTMonitorInfoTypeAll) {
        [tag appendFormat:@"memory_total=%lld,",[ZYBaseInfoHander getTotalMemorySize]];
    }
    if (self.config.monitorInfoType &FTMonitorInfoTypeCpu || self.config.monitorInfoType & FTMonitorInfoTypeAll) {
        [tag appendFormat:@"cpu_no=%@,",[ZYBaseInfoHander ft_getCPUType]];
    }
    if (self.config.monitorInfoType & FTMonitorInfoTypeCamera || self.config.monitorInfoType & FTMonitorInfoTypeAll) {
        [tag appendFormat:@"camera_front_px=%@,",[ZYBaseInfoHander gt_getFrontCameraPixel]];
        [tag appendFormat:@"camera_back_px=%@,",[ZYBaseInfoHander gt_getBackCameraPixel]];
    }
     _tag = [tag stringByReplacingOccurrencesOfString:@" " withString:@"\\ "];
     return _tag;
}
- (NSString *)getBasicData{
    NSString *basicTag = [self basicTags];
    /*
     battery_total
     network_speed
     */
    if (self.config.monitorInfoType &FTMonitorInfoTypeCpu || self.config.monitorInfoType & FTMonitorInfoTypeAll) {
        basicTag =  [basicTag stringByAppendingFormat:@"cpu_use=%ld%%,",[ZYBaseInfoHander ft_cpuUsage]];
    }
    if (self.config.monitorInfoType & FTMonitorInfoTypeMemory || self.config.monitorInfoType & FTMonitorInfoTypeAll) {
        basicTag=  [basicTag stringByAppendingFormat:@"memory_use=%@,",[ZYBaseInfoHander usedMemory]];
    }
    if (self.config.monitorInfoType & FTMonitorInfoTypeNetwork || self.config.monitorInfoType & FTMonitorInfoTypeAll) {
       __block NSString *network_type,*network_strength;
        dispatch_sync(dispatch_get_main_queue(), ^{
            network_type =[FTNetworkInfo getNetworkType];
            network_strength = [NSString stringWithFormat:@"%d",[FTNetworkInfo getNetSignalStrength]];
        });
        basicTag =[basicTag stringByAppendingFormat:@"network_type=%@,",network_type];
        basicTag =[basicTag stringByAppendingFormat:@"network_strength=%@,",network_strength];
        basicTag =[basicTag stringByAppendingFormat:@"network_speed=%@,",self.netFlow.flow];

    }
    if (self.config.monitorInfoType & FTMonitorInfoTypeBattery || self.config.monitorInfoType & FTMonitorInfoTypeAll) {
        basicTag =[basicTag stringByAppendingFormat:@"battery_use=%@,",[ZYBaseInfoHander ft_getBatteryUse]];
    }
    basicTag = [basicTag stringByReplacingOccurrencesOfString:@" " withString:@"\\ "];
    return basicTag;
}

@end
