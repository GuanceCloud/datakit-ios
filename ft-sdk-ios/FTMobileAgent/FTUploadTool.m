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
#import "FTMonitorUtils.h"
#import "NSDate+FTAdd.h"
typedef NS_OPTIONS(NSInteger, FTParameterType) {
    FTParameterTypetTag          = 1,
    FTParameterTypeField     = 2 ,
    FTParameterTypeUser      = 3 ,
};
typedef NS_OPTIONS(NSInteger, FTCheckTokenState) {
    FTCheckTokenStateLoading  = 1,
    FTCheckTokenStatePass     = 2,
    FTCheckTokenStateError    = 3,
    FTCheckTokenStateNetError = 4
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
        if ([self.field isEqualToString:FT_KEY_DURATION]) {
            return [NSString stringWithFormat:@"%@=%@i", [FTBaseInfoHander repleacingSpecialCharacters:self.field], self.value];;
        }
        if([self.value isKindOfClass:NSString.class]){
            return [NSString stringWithFormat:@"%@=\"%@\"", [FTBaseInfoHander repleacingSpecialCharacters:self.field], [FTBaseInfoHander repleacingSpecialCharactersField:self.value]];
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

@interface FTUploadTool()
@property (nonatomic, assign) BOOL isUploading;
@property (nonatomic, assign) FTCheckTokenState checkTokenState;
@property (nonatomic, strong) NSDictionary *basicTags;
@property (nonatomic, strong) NSURLSession *session;
/// 网络请求调用结束的 Block 所在的线程
@property (nonatomic, strong) NSOperationQueue *operationQueue;
@end
@implementation FTUploadTool
-(instancetype)initWithConfig:(FTMobileConfig *)config{
    self = [super init];
    if (self) {
        self.config = config;
        _operationQueue = [[NSOperationQueue alloc] init];
        _operationQueue.maxConcurrentOperationCount = 1;
        if (config.datawayToken) {
            [self checkToken];
        }else{
            self.checkTokenState = FTCheckTokenStatePass;
        }
    }
    return self;
}

-(void)upload{
    if(self.checkTokenState == FTCheckTokenStateNetError){
        [self checkToken];
        self.isUploading = NO;
        return;
    }
    if (self.checkTokenState == FTCheckTokenStatePass) {
    if (!self.isUploading) {
        //当前数据库所有数据
        self.isUploading = YES;
        [self flushQueue];
    }
    }
}
- (void)flushQueue{
    @try {
        [self flushWithType:FTNetworkingTypeObject];
        [self flushWithType:FTNetworkingTypeLogging];
        [self flushWithType:FTNetworkingTypeMetrics];
        [self flushWithType:FTNetworkingTypeKeyevent];
        self.isUploading = NO;
    } @catch (NSException *exception) {
        ZYDebug(@"执行上传操作失败 %@",exception);
    }
}
-(void)checkToken{
    self.checkTokenState = FTCheckTokenStateLoading;
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@%@",self.config.metricsUrl,FT_NETWORKING_API_CHECK_TOKEN,self.config.datawayToken]];
    NSMutableURLRequest *mutableRequest = [NSMutableURLRequest requestWithURL:url];
    mutableRequest.HTTPMethod = @"GET";
    NSURLSessionTask *task = [self dataTaskWithRequest:mutableRequest completionHandler:^(NSData * _Nullable data, NSHTTPURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error || ![response isKindOfClass:[NSHTTPURLResponse class]]) {
            ZYDebug(@"%@", [NSString stringWithFormat:@"Network failure: %@", error ? error : @"Unknown error"]);
            self.checkTokenState = FTCheckTokenStateNetError;
            return;
        }
        NSInteger statusCode = response.statusCode;
        if (statusCode >= 500 && statusCode < 600) {
            self->_checkTokenState = FTCheckTokenStateNetError;
            return;
        }else if (statusCode ==200){
            NSMutableDictionary *responseObject;
            NSError *errors;
            responseObject = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&errors];
            if ([responseObject valueForKey:@"code"] && [responseObject[@"code"] intValue] == 200){
                self.checkTokenState = FTCheckTokenStatePass;
                return;
            }
        }
        self->_checkTokenState = FTCheckTokenStateError;
        ZYErrorLog(@"Dataflux SDK 未能验证通过您配置的 token");
    }];
    [task resume];
}
-(BOOL)flushWithType:(NSString *)op{
    NSArray *events;
    if (self.config.needBindUser && [op isEqualToString:FTNetworkingTypeMetrics]) {
        events = [[FTTrackerEventDBTool sharedManger] getFirstTenBindUserData:op];
    }else{
        events = [[FTTrackerEventDBTool sharedManger] getFirstTenData:op];
    }
    if (events.count == 0 || ![self flushWithEvents:events]) {
        return NO;
    }
    FTRecordModel *model = [events lastObject];
    if (![[FTTrackerEventDBTool sharedManger] deleteItemWithType:op tm:model.tm]) {
        ZYErrorLog(@"数据库删除已上传数据失败");
        return NO;
    }
   return [self flushWithType:op];
}
-(BOOL)flushWithEvents:(NSArray *)events{
    @try {
        ZYDebug(@"开始上报事件(本次上报事件数:%lu)", (unsigned long)[events count]);
        __block BOOL success = NO;
        dispatch_semaphore_t  flushSemaphore = dispatch_semaphore_create(0);
        [self trackList:events callBack:^(NSData * _Nullable data, NSHTTPURLResponse * _Nullable response, NSError * _Nullable error) {
            if (error || ![response isKindOfClass:[NSHTTPURLResponse class]]) {
                ZYErrorLog(@"%@", [NSString stringWithFormat:@"Network failure: %@", error ? error : @"Unknown error"]);
                success = NO;
                dispatch_semaphore_signal(flushSemaphore);
                return;
            }
            NSInteger statusCode = response.statusCode;
            success = (statusCode >=200 && statusCode < 500);
            if (!success) {
                ZYErrorLog(@"服务器异常 稍后再试 response = %@",response);
            }
            dispatch_semaphore_signal(flushSemaphore);
        }];
        dispatch_semaphore_wait(flushSemaphore, DISPATCH_TIME_FOREVER);
        return success;
    }
    @catch (NSException *exception) {
        ZYErrorLog(@"exception %@",exception);
    }
}
-(void)trackImmediate:(FTRecordModel *)model callBack:(FTURLTaskCompletionHandler)callBack{
    [self trackImmediateList:@[model] callBack:callBack];
}
-(void)trackImmediateList:(NSArray <FTRecordModel *>*)modelList callBack:(FTURLTaskCompletionHandler)callBack{
    if (self.checkTokenState == FTCheckTokenStateError) {
       callBack?callBack(UnknownException, nil):nil;
        return;
    }
    FTURLSessionTaskCompletionHandler handler = ^(NSData * _Nullable data, NSHTTPURLResponse * _Nullable response, NSError * _Nullable error){
        if (error || ![response isKindOfClass:[NSHTTPURLResponse class]]) {
            callBack? callBack(error.code, nil):nil;
        }
        callBack?callBack([(NSHTTPURLResponse *)response statusCode], data):nil;
    };
    [self trackList:modelList callBack:handler];
}
-(void)trackList:(NSArray <FTRecordModel *>*)modelList callBack:(FTURLSessionTaskCompletionHandler)callBack{
    FTRecordModel *model = [modelList firstObject];
      NSString *api = nil;
      if ([model.op isEqualToString:FTNetworkingTypeObject]) {
          NSString *token = self.config.datawayToken?[NSString stringWithFormat:@"?token=%@",self.config.datawayToken]:@"";
          NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@%@",self.config.metricsUrl,FT_NETWORKING_API_OBJECT,token]];
          [self objectRequestWithURL:url eventsAry:modelList callBack:callBack];
          return;
      }
      if ([model.op isEqualToString:FTNetworkingTypeMetrics])
      {   api = FT_NETWORKING_API_METRICS;
      }
      if ([model.op isEqualToString:FTNetworkingTypeLogging]) {
          api = FT_NETWORKING_API_LOGGING;
      }
      if ([model.op isEqualToString:FTNetworkingTypeKeyevent]) {
          api = FT_NETWORKING_API_KEYEVENT;
      }
      NSString *token = self.config.datawayToken?[NSString stringWithFormat:@"?token=%@",self.config.datawayToken]:@"";
      NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@%@",self.config.metricsUrl,api,token]];
      [self trackRequestWithURL:url eventsAry:modelList callBack:callBack];
}
- (void)trackRequestWithURL:(NSURL *)url eventsAry:(NSArray *)events callBack:(FTURLSessionTaskCompletionHandler)callBack{
    NSURLRequest *request = [self lineProtocolRequestWithURL:url datas:events];
    //设置网络请求的返回接收器
    NSURLSessionTask *dataTask = [self dataTaskWithRequest:request completionHandler:callBack];
    //开始请求
    [dataTask resume];
}
- (void)objectRequestWithURL:(NSURL *)url eventsAry:(NSArray *)events callBack:(FTURLSessionTaskCompletionHandler)callBack{
    NSMutableArray *list = [NSMutableArray new];
      [events enumerateObjectsUsingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
          NSMutableDictionary *item = [FTBaseInfoHander ft_dictionaryWithJsonString:obj.data].mutableCopy;
          NSMutableDictionary *tag = [item valueForKey:FT_KEY_TAGS];
          if ([[item allKeys] containsObject:FT_AGENT_OP]) {
              [tag addEntriesFromDictionary:self.basicTags];
              [tag setValue:[FTMonitorUtils userDeviceName] forKey:FT_MONITOR_DEVICE_NAME];
              [tag removeObjectForKey:FT_COMMON_PROPERTY_DISPLAY];
          }
          [item setValue:tag forKey:FT_KEY_TAGS];
          [list addObject:item];
      }];
    // 待处理 object 类型
    NSURLRequest *request = [self writeObjectRequestWithURL:url datas:list];
    //设置网络请求的返回接收器
    NSURLSessionTask *dataTask = [self dataTaskWithRequest:request completionHandler:callBack];
    //开始请求
    [dataTask resume];
}
// metrics、logging、keyevent
-(NSURLRequest *)lineProtocolRequestWithURL:(NSURL *)url datas:(NSArray *)datas{
    NSString *requestData = [self getRequestDataWithEventArray:datas];
    ZYLog(@"requestData = %@",requestData);
    return  [self getRequestWithURL:url body:requestData contentType:@"text/plain"];
}
// object
-(NSURLRequest *)writeObjectRequestWithURL:(NSURL *)url datas:(NSArray *)datas{
    NSString *requestData = [self arrayToJSONString:datas];
    ZYLog(@"requestData = %@",requestData);
    return  [self getRequestWithURL:url body:requestData contentType:@"application/json"];
}
-(NSURLRequest *)getRequestWithURL:(NSURL *)url body:(id)body contentType:(NSString *)contentType{
    NSMutableURLRequest *mutableRequest = [NSMutableURLRequest requestWithURL:url];
     NSString *date =[[NSDate date] ft_dateGMT];
     mutableRequest.HTTPMethod = @"POST";
     //添加header
     [mutableRequest addValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
     [mutableRequest addValue:contentType forHTTPHeaderField:@"Content-Type"];
     [mutableRequest addValue:@"charset=utf-8" forHTTPHeaderField:@"Content-Type"];
     [mutableRequest setValue:@"application/json" forHTTPHeaderField:@"Accept"];
     //设置请求参数
     [mutableRequest setValue:self.config.XDataKitUUID forHTTPHeaderField:@"X-Datakit-UUID"];
     [mutableRequest setValue:date forHTTPHeaderField:@"Date"];
     [mutableRequest setValue:FT_USER_AGENT forHTTPHeaderField:@"User-Agent"];
     [mutableRequest setValue:@"zh-CN" forHTTPHeaderField:@"Accept-Language"];
     mutableRequest.HTTPBody = [body dataUsingEncoding:NSUTF8StringEncoding];
     if (self.config.enableRequestSigning) {
         NSString *authorization = [NSString stringWithFormat:@"DWAY %@:%@",self.config.akId,[FTBaseInfoHander ft_getSSOSignWithRequest:mutableRequest akSecret:self.config.akSecret data:body]];
         [mutableRequest addValue:authorization forHTTPHeaderField:@"Authorization"];
     }
     return mutableRequest;
}

#pragma mark - request
- (NSURLSessionTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(FTURLSessionTaskCompletionHandler)completionHandler {
    return [self.session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error || ![response isKindOfClass:[NSHTTPURLResponse class]]) {
            completionHandler?completionHandler(nil, nil, error):nil;
        }
        completionHandler?completionHandler(data, (NSHTTPURLResponse *)response, error):nil;
    }];
}

-(NSURLSession *)session{
    if(!_session){
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        config.timeoutIntervalForRequest = 30.0;
        _session = [NSURLSession sessionWithConfiguration:config delegate:nil delegateQueue:self.operationQueue];
    }
    return _session;
}
//结束请求
- (void)stopLoading {
    [self.session invalidateAndCancel];
    self.session = nil;
}
#pragma mark ========== requestHTTPBody 数据处理 ==========
- (NSString *)getRequestDataWithEventArray:(NSArray *)events{
    __block NSMutableString *requestDatas = [NSMutableString new];
    [events enumerateObjectsUsingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *item = [FTBaseInfoHander ft_dictionaryWithJsonString:obj.data];
        NSDictionary *userData = [FTBaseInfoHander ft_dictionaryWithJsonString:obj.userdata];
        NSString *field = @"";
        NSDictionary *opdata =item[FT_AGENT_OPDATA];
        NSString *measurement =[FTBaseInfoHander repleacingSpecialCharactersMeasurement:[opdata valueForKey:FT_AGENT_MEASUREMENT]];
        NSMutableDictionary *tagDict = [NSMutableDictionary dictionaryWithDictionary:opdata[FT_AGENT_TAGS]];
        if (![obj.op isEqualToString:FTNetworkingTypeLogging] && ![obj.op isEqualToString:FTNetworkingTypeKeyevent]) {
            [tagDict addEntriesFromDictionary:self.basicTags];
        }
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
- (NSString *)arrayToJSONString:(NSArray *)array {
    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:array options:NSJSONWritingPrettyPrinted error:&error];
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    ZYDebug(@"jsonArray = %@",jsonString);
    return jsonString;
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
-(void)dealloc{
    [self.session invalidateAndCancel];
}

@end
