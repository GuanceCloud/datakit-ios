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
#import "FTLog.h"
#import "FTRecordModel.h"
#import "FTMobileConfig.h"
#import "FTNetworkInfo.h"
#import <objc/runtime.h>
#import "FTConstants.h"

typedef NS_OPTIONS(NSInteger, FTParameterType) {
    FTParameterTypetTag          = 1,
    FTParameterTypeField     = 2 ,
    FTParameterTypeUser      = 3 ,
};

#pragma mark ========== 参数处理 ==========

@interface FTQueryStringPair : NSObject
@property (readwrite, nonatomic, strong) NSString *field;
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
        return [NSString stringWithFormat:@"%@=%@", [FTBaseInfoHander repleacingSpecialCharacters:self.field],FT_NULL_VALUE];
    } else {
        return [NSString stringWithFormat:@"%@=%@", [FTBaseInfoHander repleacingSpecialCharacters:self.field], [FTBaseInfoHander repleacingSpecialCharacters:self.value]];
    }
}
- (NSString *)URLEncodedFiledStringValue{
    if (!self.value || [self.value isEqual:[NSNull null]]) {
        return [NSString stringWithFormat:@"%@=%@", [FTBaseInfoHander repleacingSpecialCharacters:self.field],FT_NULL_VALUE];
    }else{
        if ([self.field isEqualToString:FT_FLOW_DURATION]) {
            return [NSString stringWithFormat:@"%@=%@i", [FTBaseInfoHander repleacingSpecialCharacters:self.field], self.value];;
        }
        if([self.value isKindOfClass:NSString.class]){
            return [NSString stringWithFormat:@"%@=\"%@\"", [FTBaseInfoHander repleacingSpecialCharacters:self.field], self.value];
        }else if([self.value isKindOfClass:NSNumber.class]){
            NSNumber *number = self.value;
            if (abs(number.intValue) <fabsf(number.floatValue) || abs(number.intValue)<fabs(number.doubleValue)) {
                return [NSString stringWithFormat:@"%@=%.2f", [FTBaseInfoHander repleacingSpecialCharacters:self.field], number.floatValue];
            }
        }
        return [NSString stringWithFormat:@"%@=%@", [FTBaseInfoHander repleacingSpecialCharacters:self.field], self.value];
    }
}
@end

@interface FTUploadTool()<NSURLSessionTaskDelegate>
@property (nonatomic, assign) BOOL isUploading;
@property (nonatomic, strong) NSDictionary *basicTags;
@property (nonatomic, strong) NSURLSession *session;

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
            __block BOOL success = NO;
            dispatch_group_t group = dispatch_group_create();
            dispatch_group_enter(group);
            [self apiRequestWithEventsAry:updata callBack:^(NSInteger statusCode, NSData *response) {
                if (statusCode ==200) {
                    NSMutableDictionary *responseObject;
                    
                    NSError *errors;
                    responseObject = [NSJSONSerialization JSONObjectWithData:response options:NSJSONReadingMutableContainers error:&errors];
                    if ([responseObject valueForKey:@"code"] && [responseObject[@"code"] intValue] == 200) {
                        success = YES;
                    }else{
                        if (errors){
                            ZYDebug(@"response error = %@",errors);
                        }else {
                            ZYDebug(@"responseObject = %@",responseObject);
                        }
                        success = NO;
                    }
                }else{
                    ZYDebug(@"response = %@",response);
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
-(void)trackImmediate:(FTRecordModel *)model callBack:(FTURLTaskCompletionHandler)callBack{
    [self apiRequestWithEventsAry:@[model] callBack:callBack];
}
-(void)trackImmediateList:(NSArray <FTRecordModel *>*)modelList callBack:(FTURLTaskCompletionHandler)callBack{
    [self apiRequestWithEventsAry:modelList callBack:callBack];
}

- (void)apiRequestWithEventsAry:(NSArray *)events callBack:(FTURLTaskCompletionHandler)callBack{
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
        NSString *authorization = [NSString stringWithFormat:@"DWAY %@:%@",self.config.akId,[FTBaseInfoHander ft_getSSOSignWithRequest:mutableRequest akSecret:self.config.akSecret data:requestData]];
        [mutableRequest addValue:authorization forHTTPHeaderField:@"Authorization"];
    }
    request = [mutableRequest copy];
    //设置网络请求的返回接收器
    NSURLSessionDataTask *dataTask = [self.session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        BOOL success= NO;
        if (error) {
            callBack? callBack(error.code,nil):nil ;
        }else{
            success = YES;
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            NSInteger statusCode = [httpResponse statusCode];
            callBack? callBack(statusCode,data):nil ;
        }
    }];
    //开始请求
    [dataTask resume];
    
}
-(NSURLSession *)session{
    if(!_session){
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        config.timeoutIntervalForRequest = 30.0;
        _session = [NSURLSession sessionWithConfiguration:config];
    }
    return _session;
}
//结束请求
- (void)stopLoading {
    [self.session invalidateAndCancel];
    self.session = nil;
}

- (NSString *)getRequestDataWithEventArray:(NSArray *)events{
    __block NSMutableString *requestDatas = [NSMutableString new];
    [events enumerateObjectsUsingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *item = [FTBaseInfoHander ft_dictionaryWithJsonString:obj.data];
        NSDictionary *userData = [FTBaseInfoHander ft_dictionaryWithJsonString:obj.userdata];
        NSString *field = @"";
        NSDictionary *opdata =item[FT_AGENT_OPDATA];
        NSString *measurement =[FTBaseInfoHander repleacingSpecialCharactersMeasurement:[opdata valueForKey:FT_AGENT_MEASUREMENT]];
        NSMutableDictionary *tagDict = [NSMutableDictionary dictionaryWithDictionary:opdata[FT_AGENT_TAGS]];
        
        [tagDict addEntriesFromDictionary:self.basicTags];
     
        if ([[opdata allKeys] containsObject:FT_AGENT_FIELD]) {
            field=FTQueryStringFromParameters(opdata[FT_AGENT_FIELD],FTParameterTypeField);
        }
        if (userData.allKeys.count>0) {
            NSDictionary *userDict =  FTQueryPairsFromUserDict(userData);
            [tagDict addEntriesFromDictionary:userDict];
        }
        NSString *tagsStr = FTQueryStringFromParameters(tagDict,FTParameterTypetTag);
        
        NSString *requestStr = tagsStr.length>0? [NSString stringWithFormat:@"%@,%@ %@ %lld",measurement,tagsStr,field,obj.tm*1000]:[NSString stringWithFormat:@"%@ %@ %lld",measurement,field,obj.tm*1000];
        if (idx==0) {
            [requestDatas appendString:requestStr];
        }else{
            [requestDatas appendFormat:@"\n%@",requestStr];
        }
        ZYDebug(@"-------%d-------",idx);
        ZYDebug(@"%@",@{FT_AGENT_MEASUREMENT:measurement,
                        FT_AGENT_TAGS:tagDict,
                        FT_AGENT_FIELD:opdata[FT_AGENT_FIELD],
                        @"time":[NSNumber numberWithLongLong:obj.tm*1000],
                      });
    }];
    return requestDatas;
}
- (NSDictionary *)getLastNetInfo{
    NSDictionary *net;
    return net;
}
- (NSDictionary *)basicTags{
    if (!_basicTags) {
        NSDictionary *deviceInfo = [FTBaseInfoHander ft_getDeviceInfo];
        NSString * uuid =[[UIDevice currentDevice] identifierForVendor].UUIDString;
        NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
        CFShow((__bridge CFTypeRef)(infoDictionary));
        NSString *identifier = [infoDictionary objectForKey:@"CFBundleIdentifier"];
        NSString *preferredLanguage = [[[NSBundle mainBundle] preferredLocalizations] firstObject];
        NSString *version = [UIDevice currentDevice].systemVersion;
        NSMutableDictionary *tag = @{FT_COMMON_PROPERTY_DEVICE_UUID:uuid,
                                     FT_COMMON_PROPERTY_APPLICATION_IDENTIFIER:identifier,
                                     FT_COMMON_PROPERTY_APPLICATION_NAME:self.config.appName,
                                     FT_COMMON_PROPERTY_OS:@"iOS",
                                     FT_COMMON_PROPERTY_OS_VERSION:version,
                                     FT_COMMON_PROPERTY_DEVICE_BAND:@"APPLE",
                                     FT_COMMON_PROPERTY_LOCALE:preferredLanguage,
                                     FT_COMMON_PROPERTY_DEVICE_MODEL:deviceInfo[FTBaseInfoHanderDeviceType],
                                     FT_COMMON_PROPERTY_DISPLAY:[FTBaseInfoHander ft_resolution],
                                     FT_COMMON_PROPERTY_CARRIER:[FTBaseInfoHander ft_getTelephonyInfo],
                                     FT_COMMON_PROPERTY_AGENT:self.config.sdkAgentVersion,
                                     
        }.mutableCopy;
        self.config.sdkTrackVersion.length>0?[tag setObject:self.config.sdkTrackVersion forKey:FT_COMMON_PROPERTY_AUTOTRACK]:nil;
         ;
        _basicTags = tag;
    }
    return _basicTags;
}

NSString * FTQueryStringFromParameters(NSDictionary *parameters,FTParameterType type) {
    NSMutableArray *mutablePairs = [NSMutableArray array];
    for (FTQueryStringPair *pair in FTQueryStringPairsFromKeyAndValue(nil,parameters,type)) {
        if (type == FTParameterTypeField) {
            [mutablePairs addObject:[pair URLEncodedFiledStringValue]];
        }else{
            [mutablePairs addObject:[pair URLEncodedTagsStringValue]];
        }
    }
    
    return [mutablePairs componentsJoinedByString:@","];
}
NSArray * FTQueryStringPairsFromKeyAndValue(NSString *key, id value,FTParameterType type) {
    NSMutableArray *mutableQueryStringComponents = [NSMutableArray array];
    if ([value isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dictionary = value;
        for (id nestedKey in dictionary.allKeys) {
            id nestedValue = dictionary[nestedKey];
            if (nestedValue) {
                [mutableQueryStringComponents addObjectsFromArray:FTQueryStringPairsFromKeyAndValue( nestedKey, nestedValue,type)];
            }
        }
    }else{
        if (type == FTParameterTypeUser) {
            [mutableQueryStringComponents addObject:[[FTQueryStringPair alloc] initWithUserField:key value:value]];
        }else{
            [mutableQueryStringComponents addObject:[[FTQueryStringPair alloc] initWithField:key value:value]];
        }
    }
    return mutableQueryStringComponents;
}
//循环遍历userData字典  key 添加 ud_  去除嵌套字典
NSDictionary * FTQueryPairsFromUserDict(NSDictionary *parameters) {
    NSMutableDictionary *mutableUserDictgComponents = [NSMutableDictionary new];
    for (FTQueryStringPair *pair in FTQueryStringPairsFromKeyAndValue(nil,parameters,FTParameterTypeUser)) {
        [mutableUserDictgComponents setValue:pair.value forKey:pair.field];
    }
    return mutableUserDictgComponents;
}
@end
