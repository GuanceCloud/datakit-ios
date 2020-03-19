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

#pragma mark -

@interface FTQueryStringPair : NSObject
@property (readwrite, nonatomic, strong) id field;
@property (readwrite, nonatomic, strong) id value;

- (instancetype)initWithField:(id)field value:(id)value;
- (instancetype)initWithUserField:(id)field value:(id)value;
- (NSString *)URLEncodedTagsStringValue;
- (NSString *)URLEncodedFiledStringValue;
@end
@implementation FTQueryStringPair
- (instancetype)initWithField:(id)field value:(id)value {
    self = [super init];
    if (!self) {
        return nil;
    }
    
    self.field = field;
    self.value = value;
    //旧数据处理 1.0.1-alpha9之前
    if ([field isEqualToString:@"cpn"]) {
        self.value = @"current_page_name";
    }
    if ([field isEqualToString:@"rpn"]) {
        self.value = @"root_page_name";
    }
    return self;
}
- (instancetype)initWithUserField:(id)field value:(id)value{
    self = [super init];
    if (!self) {
        return nil;
    }
    
    self.field = [NSString stringWithFormat:@"ud_%@",field];
    self.value = value;
    return self;
}
- (NSString *)URLEncodedTagsStringValue{
    if (!self.value || [self.value isEqual:[NSNull null]]) {
        return [NSString stringWithFormat:@"%@=null", [self repleacingSpecialCharacters:self.field]];
    } else {
        return [NSString stringWithFormat:@"%@=%@", [self repleacingSpecialCharacters:self.field], [self repleacingSpecialCharacters:self.value]];
    }
}
- (NSString *)URLEncodedFiledStringValue{
    if (!self.value || [self.value isEqual:[NSNull null]]) {
        return [NSString stringWithFormat:@"%@=null", [self repleacingSpecialCharacters:self.field]];
    } else if([self.field isEqualToString:@"$duration"]){
        return [NSString stringWithFormat:@"%@=%@", [self repleacingSpecialCharacters:self.field], self.value];
    }else{
        return [NSString stringWithFormat:@"%@=\"%@\"", [self repleacingSpecialCharacters:self.field], self.value];
    }
}
- (id )repleacingSpecialCharacters:(id )str{
    if ([str isKindOfClass:NSString.class]) {
        NSString *reStr = [str stringByReplacingOccurrencesOfString:@"," withString:@"\\,"];
        reStr =[reStr stringByReplacingOccurrencesOfString:@"=" withString:@"\\="];
        reStr =[reStr stringByReplacingOccurrencesOfString:@"，" withString:@"\\，"];
        reStr = [str stringByReplacingOccurrencesOfString:@" " withString:@"\\ "];
        return reStr;
    }else{
        return str;
    }
    
}
@end

@interface FTUploadTool()
@property (nonatomic, assign) BOOL isUploading;
@property (nonatomic, strong) FTMobileConfig *config;
@property (nonatomic, strong) dispatch_queue_t timerQueue;
@property (nonatomic, copy) NSString *basicTagStr;
@property (nonatomic, strong) NSDictionary *basicTags;
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
            __block BOOL success;
            dispatch_group_t group = dispatch_group_create();
            dispatch_group_enter(group);
            [self apiRequestWithEventsAry:updata callBack:^(NSInteger statusCode, id responseObject) {
                if ([responseObject valueForKey:@"code"] && [responseObject[@"code"] intValue] == 200) {
                    success = YES;
                }else{
                    success = NO;
                }
                dispatch_group_leave(group);
            }];
            dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
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
-(void)trackImmediate:(FTRecordModel *)model callBack:(nonnull void (^)(NSInteger, id _Nonnull))callBack{
    [self apiRequestWithEventsAry:@[model] callBack:^(NSInteger statusCode, id responseObject) {
        callBack?callBack(statusCode,responseObject):nil;
    }];
    
}
-(void)trackImmediateList:(NSArray <FTRecordModel *>*)modelList callBack:(nonnull void (^)(NSInteger, id _Nonnull))callBack{
    [self apiRequestWithEventsAry:modelList callBack:^(NSInteger statusCode, id responseObject) {
        callBack?callBack(statusCode,responseObject):nil;
    }];
}
- (void)apiRequestWithEventsAry:(NSArray *)events callBack:(nonnull void (^)(NSInteger statusCode, id responseObject))callBack {
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
    
    //设置网络请求的返回接收器
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        NSInteger statusCode = [httpResponse statusCode];
        NSMutableDictionary *responseObject;
        if (error) {
            ZYDebug(@"response error = %@",error);
        }else{
            NSError *errors;
            responseObject = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&errors];
            if (errors){
                ZYDebug(@"response error = %@",error);
            }else {
                ZYDebug(@"responseObject = %@",responseObject);
            }
            
        }
        callBack? callBack(statusCode,responseObject):nil ;
        
    }];
    //开始请求
    [dataTask resume];
    
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
                    field = [field stringByAppendingFormat:@"$duration=%@,",[opdata valueForKey:@"duration"]];
                }
            }else{
                if ([opdata valueForKey:@"measurement"]) {
                    firstStr = [opdata valueForKey:@"measurement"];
                }
            }
            if ([[opdata allKeys] containsObject:@"field"]) {
                field=field.length>0?[field stringByAppendingFormat:@",%@",FTFiledQueryStringFromParameters(opdata[@"field"])]:FTFiledQueryStringFromParameters(opdata[@"field"]);
            }
            NSString *tagsStr  = FTTagQueryStringFromParameters(opdata[@"tags"]);
            NSString *userStr =userData.allKeys.count>0?  userStr=FTUserQueryStringFromParameters(userData):nil;
            
            requestStr =firstStr;
            requestStr = [requestStr stringByAppendingFormat:@",%@,%@",tagsStr,self.basicTagStr];
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
    __block NSString *event = @"";
    
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
    NSString *tagsStr  = FTTagQueryStringFromParameters(opdata[@"tags"]);
    NSString *userStr =userData.allKeys.count>0?  userStr=FTUserQueryStringFromParameters(userData):nil;
    
    if ([[opdata allKeys] containsObject:@"duration"]) {
        event = [event stringByAppendingFormat:@"$duration=%@",[opdata valueForKey:@"duration"]];
    }
    if ([[opdata allKeys] containsObject:@"values"]) {
        
        event =event.length==0? FTFiledQueryStringFromParameters(opdata[@"values"]):[event stringByAppendingFormat:@",%@",FTFiledQueryStringFromParameters(opdata[@"values"])];
    }
    tagsStr = userStr.length>0?[tagsStr stringByAppendingFormat:@",%@,%@",self.basicTagStr,userStr]:[tagsStr stringByAppendingFormat:@",%@",self.basicTagStr];
    NSString *requestStr =firstStr;
    requestStr = [requestStr stringByAppendingFormat:@",%@",tagsStr];
    requestStr = [requestStr stringByAppendingFormat:@" %@ %lld",event,model.tm*1000];
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
- (NSDictionary *)basicTags{
    if (!_basicTags) {
        NSDictionary *deviceInfo = [FTBaseInfoHander ft_getDeviceInfo];
        NSString * uuid =[[UIDevice currentDevice] identifierForVendor].UUIDString;
        NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
        CFShow((__bridge CFTypeRef)(infoDictionary));
        NSString *app_Name = [infoDictionary objectForKey:@"CFBundleDisplayName"];
        NSString *identifier = [infoDictionary objectForKey:@"CFBundleIdentifier"];
        
        NSString *preferredLanguage = [[[NSBundle mainBundle] preferredLocalizations] firstObject];
        NSString *version = [UIDevice currentDevice].systemVersion;
        NSMutableDictionary *tag = @{@"device_uuid":uuid,
                                     @"application_identifier":identifier,
                                     @"application_name":app_Name,
                                     @"os":@"iOS",
                                     @"os_version":version,
                                     @"device_band":@"APPLE",
                                     @"locale":preferredLanguage,
                                     @"device_model":deviceInfo[FTBaseInfoHanderDeviceType],
                                     @"display":[FTBaseInfoHander ft_resolution],
                                     @"carrier":[FTBaseInfoHander ft_getTelephonyInfo],
                                     
        }.mutableCopy;
        if (self.config.monitorInfoType &FTMonitorInfoTypeBattery || self.config.monitorInfoType & FTMonitorInfoTypeAll) {
            [tag setObject:deviceInfo[FTBaseInfoHanderBatteryTotal] forKey:@"battery_total"];
        }
        if (self.config.monitorInfoType & FTMonitorInfoTypeMemory || self.config.monitorInfoType & FTMonitorInfoTypeAll) {
            [tag setObject:[NSNumber numberWithLongLong:[FTBaseInfoHander ft_getTotalMemorySize]] forKey:@"memory_total"];
        }
        if (self.config.monitorInfoType &FTMonitorInfoTypeCpu || self.config.monitorInfoType & FTMonitorInfoTypeAll) {
            [tag setObject:deviceInfo[FTBaseInfoHanderDeviceCPUType] forKey:@"cpu_no"];
            [tag setObject:deviceInfo[FTBaseInfoHanderDeviceCPUClock] forKey:@"cpu_hz"];
        }
        if(self.config.monitorInfoType &FTMonitorInfoTypeGpu || self.config.monitorInfoType & FTMonitorInfoTypeAll){
            [tag setObject:deviceInfo[FTBaseInfoHanderDeviceGPUType] forKey:@"gpu_model"];
        }
        if (self.config.monitorInfoType & FTMonitorInfoTypeCamera || self.config.monitorInfoType & FTMonitorInfoTypeAll) {
            [tag setObject:[FTBaseInfoHander ft_getFrontCameraPixel] forKey:@"camera_front_px"];
            [tag setObject:[FTBaseInfoHander ft_getBackCameraPixel] forKey:@"camera_back_px"];
        }
        _basicTags = tag;
    }
    
    return _basicTags;
}
- (NSString *)basicTagStr{
    if (!_basicTagStr) {
        NSString *tagStr = FTTagQueryStringFromParameters(self.basicTags);
        _basicTagStr = tagStr;
    }
    return _basicTagStr;
}
NSString * FTTagQueryStringFromParameters(NSDictionary *parameters) {
    NSMutableArray *mutablePairs = [NSMutableArray array];
    for (FTQueryStringPair *pair in FTQueryStringPairsFromKeyAndValue(nil,parameters)) {
        [mutablePairs addObject:[pair URLEncodedTagsStringValue]];
    }
    
    return [mutablePairs componentsJoinedByString:@","];
}
NSString * FTFiledQueryStringFromParameters(NSDictionary *parameters) {
    NSMutableArray *mutablePairs = [NSMutableArray array];
    for (FTQueryStringPair *pair in FTQueryStringPairsFromKeyAndValue(nil,parameters)) {
        [mutablePairs addObject:[pair URLEncodedFiledStringValue]];
    }
    return [mutablePairs componentsJoinedByString:@","];
}
NSString * FTUserQueryStringFromParameters(NSDictionary *parameters) {
    NSMutableArray *mutablePairs = [NSMutableArray array];
    for (FTQueryStringPair *pair in FTUserQueryStringPairsFromKeyAndValue(nil,parameters)) {
        [mutablePairs addObject:[pair URLEncodedTagsStringValue]];
    }
    return [mutablePairs componentsJoinedByString:@","];
}
NSArray * FTQueryStringPairsFromKeyAndValue(NSString *key, id value) {
    NSMutableArray *mutableQueryStringComponents = [NSMutableArray array];
    if ([value isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dictionary = value;
        for (id nestedKey in dictionary.allKeys) {
            id nestedValue = dictionary[nestedKey];
            if (nestedValue) {
                [mutableQueryStringComponents addObjectsFromArray:FTQueryStringPairsFromKeyAndValue( nestedKey, nestedValue)];
            }
        }
    }else{
        [mutableQueryStringComponents addObject:[[FTQueryStringPair alloc] initWithField:key value:value]];
        
    }
    return mutableQueryStringComponents;
}
NSArray * FTUserQueryStringPairsFromKeyAndValue(NSString *key, id value) {
    NSMutableArray *mutableQueryStringComponents = [NSMutableArray array];
    if ([value isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dictionary = value;
        for (id nestedKey in dictionary.allKeys) {
            id nestedValue = dictionary[nestedKey];
            if (nestedValue) {
                [mutableQueryStringComponents addObjectsFromArray:FTQueryStringPairsFromKeyAndValue( nestedKey, nestedValue)];
            }
        }
    }else{
        [mutableQueryStringComponents addObject:[[FTQueryStringPair alloc] initWithUserField:key value:value]];
    }
    return mutableQueryStringComponents;
}
@end
