//
//  FTUploadTool.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2019/12/3.
//  Copyright © 2019 hll. All rights reserved.
//

#import "FTUploadTool.h"
#import <UIKit/UIKit.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>
#import "FTBaseInfoHander.h"
#import "FTTrackerEventDBTool.h"
#import "ZYLog.h"
#import "FTRecordModel.h"
#import "FTMobileConfig.h"
#import "FTNetworkInfo.h"
#import <objc/runtime.h>

@interface FTUploadTool()
@property (nonatomic, assign) BOOL isUploading;
@property (nonatomic, strong) FTMobileConfig *config;
@property (nonatomic, strong) dispatch_queue_t timerQueue;
@property (nonatomic, copy) NSString *tag;
@end
@implementation FTUploadTool
-(instancetype)initWithConfig:(FTMobileConfig *)config{
     self = [super init];
       if (self) {
           self.config = config;
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
        while ([[FTTrackerEventDBTool sharedManger] getDatasCount]>0){
            ZYDebug(@"DB DATAS COUNT = %ld",[[FTTrackerEventDBTool sharedManger] getDatasCount]);
            NSArray *updata;
            if (self.config.needBindUser) {
                updata = [[FTTrackerEventDBTool sharedManger] getFirstTenDataWithUser];
            }else{
                updata = [[FTTrackerEventDBTool sharedManger] getFirstTenData];

            }
            if(updata.count == 0){
                break;
            }
         FTRecordModel *model = [updata lastObject];
         BOOL success = [self apiRequestWithEventsAry:updata andError:nil];
            if (!success) {//请求失败
                ZYDebug(@"上传事件失败");
                break;
            }
                ZYDebug(@"上传事件成功");
            BOOL delect = [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:model.tm];
            ZYDebug(@"delect == %d",delect);
        }
        self.isUploading = NO;
    }
    @catch (NSException *exception) {
         ZYDebug(@"flushQueue exception %@",exception);
    }
}
-(void)trackImmediate:(FTRecordModel *)model callBack:(void (^)(BOOL isSuccess))callBackStatus{
    BOOL success = [self apiRequestWithEventsAry:@[model] andError:nil];
    callBackStatus?callBackStatus(success):nil;
}
-(void)trackImmediateList:(NSArray <FTRecordModel *>*)modelList callBack:(void (^)(BOOL isSuccess))callBackStatus{
    BOOL success = [self apiRequestWithEventsAry:modelList andError:nil];
    callBackStatus?callBackStatus(success):nil;
}
- (BOOL)apiRequestWithEventsAry:(NSArray *)events andError:(NSError *)error {
    __block BOOL success =NO;
    __block int  retry = 0;
    NSString *requestData = [self getRequestDataWithEventArray:events];
   
        NSString *date =[FTBaseInfoHander ft_currentGMT];
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
    [mutableRequest setValue:self.config.XDataKitUUID forHTTPHeaderField:@"X-Datakit-UUID"];
        [mutableRequest setValue:date forHTTPHeaderField:@"Date"];
        [mutableRequest setValue:@"ft_mobile_sdk_ios" forHTTPHeaderField:@"User-Agent"];
        [mutableRequest setValue:@"zh-CN" forHTTPHeaderField:@"Accept-Language"];
        mutableRequest.HTTPBody = [requestData dataUsingEncoding:NSUTF8StringEncoding];
        ZYDebug(@"requestData = %@",requestData);

        if (self.config.enableRequestSigning) {
            NSString *authorization = [NSString stringWithFormat:@"DWAY %@:%@",self.config.akId,[FTBaseInfoHander ft_getSSOSignWithAkSecret:self.config.akSecret datetime:date data:requestData]];
            [mutableRequest addValue:authorization forHTTPHeaderField:@"Authorization"];
        }
        request = [mutableRequest copy];        //拷贝回去
        
 
            //设置请求session
            NSURLSession *session = [NSURLSession sharedSession];
            dispatch_group_t group = dispatch_group_create();
            dispatch_group_enter(group);

            //设置网络请求的返回接收器
            NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
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
                            if ([responseObject valueForKey:@"code"] && [responseObject[@"code"] intValue] == 200) {
                                success = YES;
                            }else{
                                success = NO;
                            }
                            ZYDebug(@"responseObject = %@",responseObject);
                        }
                    }
                     dispatch_group_leave(group);
                   
            }];
        //开始请求
            [dataTask resume];
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);

    return success;
}
- (NSString *)getRequestDataWithEventArray:(NSArray *)events{
    __block NSMutableString *requestDatas = [NSMutableString new];
    [events enumerateObjectsUsingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *item = [FTBaseInfoHander ft_dictionaryWithJsonString:obj.data];
        NSDictionary *userData = [FTBaseInfoHander ft_dictionaryWithJsonString:obj.userdata];
        
        NSString *requestStr;
        __block NSString *field = @" ";
        if ([item.allKeys containsObject:@"op"]) {
            NSString *op = [item valueForKey:@"op"];
            NSDictionary *opdata = item[@"opdata"];
            NSString *firstStr;
            
            if ([op isEqualToString:@"view"] || [op isEqualToString:@"flowcstm"]) {
                if ([opdata valueForKey:@"product"]) {
                    firstStr =[NSString stringWithFormat:@"$flow_%@",[self repleacingSpecialCharacters:[opdata valueForKey:@"product"]]];
                    firstStr= [firstStr stringByAppendingFormat:@",$traceId=%@",[self repleacingSpecialCharacters:[opdata valueForKey:@"traceId"]]];
                    firstStr= [firstStr stringByAppendingFormat:@",$name=%@",[self repleacingSpecialCharacters:[opdata valueForKey:@"name"]]];
                    if ([[opdata allKeys] containsObject:@"parent"]) {
                        firstStr= [firstStr stringByAppendingFormat:@",$parent=%@",[self repleacingSpecialCharacters:[opdata valueForKey:@"parent"]]];
                    }
                }
                if ([[opdata allKeys] containsObject:@"duration"]) {
                    field = [field stringByAppendingFormat:@"$duration=%@",[opdata valueForKey:@"duration"]];
                }
            }else{
                if ([opdata valueForKey:@"measurement"]) {
                    firstStr = [opdata valueForKey:@"measurement"];
                }
                if ([[opdata allKeys] containsObject:@"field"]) {
                    NSDictionary *fieldDict = opdata[@"field"];
                    [fieldDict enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
                        field = [field stringByAppendingFormat:@"%@=\"%@\",",[self repleacingSpecialCharacters:key],[self repleacingSpecialCharacters:obj]];
                    }];
                    field = field.length>1? [field substringToIndex:field.length-1]:field;
                }
                
            }
            __block NSString *tagsStr = [self getTagStr:opdata];
            [userData enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
                if ([obj isKindOfClass:NSString.class]) {
                    tagsStr = [tagsStr stringByAppendingFormat:@"ud_%@=%@,",[self repleacingSpecialCharacters:key],[self repleacingSpecialCharacters:obj]];
                }
                if ([obj isKindOfClass:NSDictionary.class]) {
                    [obj enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key2, id  _Nonnull obj2, BOOL * _Nonnull stop) {
                        tagsStr = [tagsStr stringByAppendingFormat:@"ud_%@=%@,",[self repleacingSpecialCharacters:key2],[self repleacingSpecialCharacters:obj2]];
                    }];
                }
            }];
            requestStr =firstStr;
            tagsStr =tagsStr.length>1? [tagsStr substringToIndex:tagsStr.length-1]:tagsStr;
            requestStr = [requestStr stringByAppendingFormat:@",%@",tagsStr];
            requestStr = [requestStr stringByReplacingOccurrencesOfString:@" " withString:@"\\ "];
            requestStr = [requestStr stringByAppendingFormat:@"%@ %lld",field,obj.tm*1000];
            
        }else{
            //遗留的旧数据 1.0.2之前
            requestStr = [self oldItemStrWithItem:obj];
        }
        if (idx==0) {
            [requestDatas appendString:requestStr];
        }else{
            [requestDatas appendFormat:@"\n%@",requestStr];
        }
        
    }];
    
    return requestDatas;
}
//1.0.0的数据
- (NSString *)oldItemStrWithItem:(FTRecordModel *)model{
    NSDictionary *item = [FTBaseInfoHander ft_dictionaryWithJsonString:model.data];
    NSDictionary *userData = [FTBaseInfoHander ft_dictionaryWithJsonString:model.userdata];
    NSDictionary *opdata = item[@"opdata"];
    NSString *firstStr;
    __block NSString *event = @" ";
    
    if ([opdata valueForKey:@"field"]) {
        firstStr = [opdata valueForKey:@"field"];
    }
    if ([opdata valueForKey:@"product"]) {
        firstStr =[NSString stringWithFormat:@"$flow_%@",[opdata valueForKey:@"product"]];
        firstStr= [firstStr stringByAppendingFormat:@",$traceId=%@",[self repleacingSpecialCharacters:[opdata valueForKey:@"traceId"]]];
        firstStr= [firstStr stringByAppendingFormat:@",$name=%@",[self repleacingSpecialCharacters:[opdata valueForKey:@"name"]]];
        if ([[opdata allKeys] containsObject:@"parent"]) {
            firstStr= [firstStr stringByAppendingFormat:@",$parent=%@",[self repleacingSpecialCharacters:[opdata valueForKey:@"parent"]]];
        }
    }
    __block NSString *tagsStr = [self getTagStr:opdata];
    [userData enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        if ([obj isKindOfClass:NSString.class]) {
            tagsStr = [tagsStr stringByAppendingFormat:@"ud_%@=%@,",[self repleacingSpecialCharacters:key],[self repleacingSpecialCharacters:obj]];
        }
        if ([obj isKindOfClass:NSDictionary.class]) {
            [obj enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key2, id  _Nonnull obj2, BOOL * _Nonnull stop) {
                tagsStr = [tagsStr stringByAppendingFormat:@"ud_%@=%@,",[self repleacingSpecialCharacters:key2],[self repleacingSpecialCharacters:obj2]];
            }];
        }
    }];
    if ([[opdata allKeys] containsObject:@"values"]) {
        NSDictionary *values = opdata[@"values"];
        [values enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            event = [event stringByAppendingFormat:@"%@=\"%@\",",[self repleacingSpecialCharacters:key],[self repleacingSpecialCharacters:obj]];
        }];
        event = event.length>1? [event substringToIndex:event.length-1]:event;
    }
    if ([[opdata allKeys] containsObject:@"duration"]) {
        event = [event stringByAppendingFormat:@"$duration=%@",[opdata valueForKey:@"duration"]];
    }
    
    tagsStr =tagsStr.length>1? [tagsStr substringToIndex:tagsStr.length-1]:tagsStr;
    NSString *requestStr =firstStr;
    requestStr = [requestStr stringByAppendingFormat:@",%@",tagsStr];
    requestStr = [requestStr stringByReplacingOccurrencesOfString:@" " withString:@"\\ "];
    requestStr = [requestStr stringByAppendingFormat:@"%@ %lld",event,model.tm*1000];
    return requestStr;
}
- (id )repleacingSpecialCharacters:(id )str{
    if ([str isKindOfClass:NSString.class]) {
      NSString *reStr = [str stringByReplacingOccurrencesOfString:@"," withString:@"\\,"];
      reStr =[reStr stringByReplacingOccurrencesOfString:@"=" withString:@"\\="];
      reStr =[reStr stringByReplacingOccurrencesOfString:@"，" withString:@"\\，"];
      return reStr;
    }else{
        return str;
    }
   
}
- (NSString *)getTagStr:(NSDictionary *)dict{
    __block NSString *tagStr = [self getBasicData];
    NSDictionary *tags =dict[@"tags"];
    
    [tags enumerateKeysAndObjectsUsingBlock:^(NSString  *key, NSString *obj, BOOL * _Nonnull stop) {
        if ([key isEqualToString:@"cpn"]) {
            if (obj) {
               tagStr = [tagStr stringByAppendingFormat:@"current_page_name=%@,",obj];
            }
        }else if ([key isEqualToString:@"rpn"]){
            if (obj && ![obj isEqualToString:@"null"]) {
                if(obj.length>0){
                tagStr =[tagStr stringByAppendingFormat:@"root_page_name=%@,",obj];
                }
            }
        }else{
            tagStr = [tagStr stringByAppendingFormat:@"%@=%@,",[self repleacingSpecialCharacters:key],[self repleacingSpecialCharacters:obj]];
        }
    }];
    return tagStr;
}
- (NSString *)getBasicData{
    if (_tag != nil) {
           return _tag;
       }
       NSDictionary *deviceInfo = [FTBaseInfoHander ft_getDeviceInfo];
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
       [tag appendFormat:@"device_model=%@,",deviceInfo[FTBaseInfoHanderDeviceType]];
       [tag appendFormat:@"display=%@,",[FTBaseInfoHander ft_resolution]];
       [tag appendFormat:@"carrier=%@,",[FTBaseInfoHander ft_getTelephonyInfo]];
    if (self.config.monitorInfoType &FTMonitorInfoTypeBattery || self.config.monitorInfoType & FTMonitorInfoTypeAll) {
        [tag appendFormat:@"battery_total=%@,",deviceInfo[FTBaseInfoHanderBatteryTotal]];
    }
    if (self.config.monitorInfoType & FTMonitorInfoTypeMemory || self.config.monitorInfoType & FTMonitorInfoTypeAll) {
        [tag appendFormat:@"memory_total=%lld,",[FTBaseInfoHander ft_getTotalMemorySize]];
    }
    if (self.config.monitorInfoType &FTMonitorInfoTypeCpu || self.config.monitorInfoType & FTMonitorInfoTypeAll) {
        [tag appendFormat:@"cpu_no=%@,",deviceInfo[FTBaseInfoHanderDeviceCPUType]];
        [tag appendFormat:@"cpu_hz=%@,",deviceInfo[FTBaseInfoHanderDeviceCPUClock]];
    }
    if(self.config.monitorInfoType &FTMonitorInfoTypeGpu || self.config.monitorInfoType & FTMonitorInfoTypeAll){
        [tag appendFormat:@"gpu_model=%@,",deviceInfo[FTBaseInfoHanderDeviceGPUType]];
    }
    if (self.config.monitorInfoType & FTMonitorInfoTypeCamera || self.config.monitorInfoType & FTMonitorInfoTypeAll) {
        [tag appendFormat:@"camera_front_px=%@,",[FTBaseInfoHander ft_getFrontCameraPixel]];
        [tag appendFormat:@"camera_back_px=%@,",[FTBaseInfoHander ft_getBackCameraPixel]];
    }
     _tag = tag;
     return _tag;
}
@end
