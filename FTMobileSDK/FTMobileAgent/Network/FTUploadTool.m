//
//  FTUploadTool.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2019/12/3.
//  Copyright © 2019 hll. All rights reserved.
//
#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif
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
#import "FTJSONUtil.h"
#import "FTMobileAgentVersion.h"
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
        if([self.value isKindOfClass:NSString.class]){
            return [NSString stringWithFormat:@"%@=\"%@\"", [FTBaseInfoHander repleacingSpecialCharacters:self.field], [FTBaseInfoHander repleacingSpecialCharactersField:self.value]];
        }else if([self.value isKindOfClass:NSNumber.class]){
            NSNumber *number = self.value;
            if (strcmp([number objCType], @encode(float)) == 0||strcmp([number objCType], @encode(double)) == 0)
            {
                return  [NSString stringWithFormat:@"%@=%.1f", [FTBaseInfoHander repleacingSpecialCharacters:self.field], number.floatValue];
            }
        }
        return [NSString stringWithFormat:@"%@=%@i", [FTBaseInfoHander repleacingSpecialCharacters:self.field], self.value];
    }
}
@end
static const NSUInteger kOnceUploadDefaultCount = 10; // 一次上传数据数量

@interface FTUploadTool()
@property (nonatomic, assign) BOOL isUploading;
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
        [self flushWithType:FT_DATA_TYPE_RUM];
        [self flushWithType:FT_DATA_TYPE_LOGGING];
        self.isUploading = NO;
    } @catch (NSException *exception) {
        ZYErrorLog(@"执行上传操作失败 %@",exception);
    }
}
-(BOOL)flushWithType:(NSString *)type{
    NSArray *events = [[FTTrackerEventDBTool sharedManger] getFirstRecords:kOnceUploadDefaultCount withType:type];
    if (events.count == 0 || ![self flushWithEvents:events]) {
        return NO;
    }
    FTRecordModel *model = [events lastObject];
    if (![[FTTrackerEventDBTool sharedManger] deleteItemWithType:type tm:model.tm]) {
        ZYErrorLog(@"数据库删除已上传数据失败");
        return NO;
    }
   return [self flushWithType:type];
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
-(NSURLRequest *)trackImmediate:(FTRecordModel *)model callBack:(FTURLTaskCompletionHandler)callBack{
   if (model == nil) {
        callBack?callBack(InvalidParamsException, nil):nil;
        return nil;
    }
   return [self trackImmediateList:@[model] callBack:callBack];
}
-(NSURLRequest*)trackImmediateList:(NSArray <FTRecordModel *>*)modelList callBack:(FTURLTaskCompletionHandler)callBack{
    if (modelList.count == 0) {
        callBack?callBack(InvalidParamsException, nil):nil;
        return nil;
    }
    FTURLSessionTaskCompletionHandler handler = ^(NSData * _Nullable data, NSHTTPURLResponse * _Nullable response, NSError * _Nullable error){
        if (error || ![response isKindOfClass:[NSHTTPURLResponse class]]) {
            callBack? callBack(error.code, nil):nil;
        }else{
        callBack?callBack([(NSHTTPURLResponse *)response statusCode], data):nil;
        }
    };
   return [self trackList:modelList callBack:handler];
}
-(NSURLRequest *)trackList:(NSArray <FTRecordModel *>*)modelList callBack:(FTURLSessionTaskCompletionHandler)callBack{
    FTRecordModel *model = [modelList firstObject];
    NSString *api = nil;
    NSURLRequest *request;
    NSString *requestData;
    NSString *contentType;
    if ([model.op isEqualToString:FT_DATA_TYPE_INFLUXDB]){
        api = FT_NETWORKING_API_METRICS;
        requestData = [self getRequestDataWithEventArray:modelList type:FT_AGENT_MEASUREMENT];
        contentType = @"text/plain";
    }else if ([model.op isEqualToString:FT_DATA_TYPE_LOGGING]) {
        api = FT_NETWORKING_API_LOGGING;
        requestData = [self getRequestDataWithEventArray:modelList type:FT_KEY_SOURCE];
        contentType = @"text/plain";
    }else if([model.op isEqualToString:FT_DATA_TYPE_RUM]){
        api = FT_NETWORKING_API_RUM;
        requestData = [self getRequestDataWithEventArray:modelList type:FT_AGENT_MEASUREMENT];
        contentType = @"text/plain";
    }else if([model.op isEqualToString:FT_DATA_TYPE_OBJECT]){
        api = FT_NETWORKING_API_OBJECT;
        requestData = [self getObjctRequestWithEventArray:modelList];
        contentType = @"application/json";
    }
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@",self.config.metricsUrl,api]];
    request = [self getRequestWithURL:url body:requestData contentType:contentType];
    //设置网络请求的返回接收器
    NSURLSessionTask *dataTask = [self dataTaskWithRequest:request completionHandler:callBack];
    //开始请求
    [dataTask resume];
    return request;
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
     [mutableRequest setValue:[NSString stringWithFormat:@"sdk_package_agent=%@",SDK_VERSION] forHTTPHeaderField:@"User-Agent"];
     [mutableRequest setValue:@"zh-CN" forHTTPHeaderField:@"Accept-Language"];
     mutableRequest.HTTPBody = [body dataUsingEncoding:NSUTF8StringEncoding];
     return mutableRequest;
}

#pragma mark - request
- (NSURLSessionTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(FTURLSessionTaskCompletionHandler)completionHandler {
    return [self.session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error || ![response isKindOfClass:[NSHTTPURLResponse class]]) {
            completionHandler?completionHandler(nil, nil, error):nil;
        }else{
        completionHandler?completionHandler(data, (NSHTTPURLResponse *)response, error):nil;
        }
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
- (NSString *)getObjctRequestWithEventArray:(NSArray *)events{
    NSMutableArray *list = [NSMutableArray new];
    [events enumerateObjectsUsingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *item = [FTJSONUtil ft_dictionaryWithJsonString:obj.data].mutableCopy;
        [list addObject:item];
    }];
    // 待处理 object 类型
    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:list options:NSJSONWritingPrettyPrinted error:&error];
    NSString *requestData = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    ZYLog(@"requestData = %@",requestData);
    return  requestData;
}
- (NSString *)getRequestDataWithEventArray:(NSArray *)events type:(NSString *)type{
    __block NSMutableString *requestDatas = [NSMutableString new];
    [events enumerateObjectsUsingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *item = [FTJSONUtil ft_dictionaryWithJsonString:obj.data];
        NSDictionary *userData = [FTJSONUtil ft_dictionaryWithJsonString:obj.userdata];
        NSString *field = @"";
        NSDictionary *opdata =item[FT_AGENT_OPDATA];
        NSString *measurement =[FTBaseInfoHander repleacingSpecialCharactersMeasurement:[opdata valueForKey:type]];
        NSDictionary *tagDict = opdata[FT_AGENT_TAGS];
        if ([[opdata allKeys] containsObject:FT_AGENT_FIELD]) {
            field=FTQueryStringFromParameters(opdata[FT_AGENT_FIELD],FTParameterTypeField);
        }
        NSString *tagsStr = tagDict.allKeys.count>0 ? FTQueryStringFromParameters(tagDict,FTParameterTypetTag):nil;
        if (userData.allKeys.count>0) {
            NSString *userStr =  FTQueryStringFromParameters(userData, FTParameterTypeUser);
            field = field.length>0?[field stringByAppendingFormat:@",%@",userStr]:userStr;
        }
        NSString *requestStr = tagsStr.length>0? [NSString stringWithFormat:@"%@,%@ %@ %lld",measurement,tagsStr,field,obj.tm*1000]:[NSString stringWithFormat:@"%@ %@ %lld",measurement,field,obj.tm*1000];
        if (idx==0) {
            [requestDatas appendString:requestStr];
        }else{
            [requestDatas appendFormat:@"\n%@",requestStr];
        }
        ZYDebug(@"-------%d-------",idx);
        
        ZYDebug(@"%@",item);
    }];
    return requestDatas;
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
-(void)dealloc{
    [self.session invalidateAndCancel];
}

@end
