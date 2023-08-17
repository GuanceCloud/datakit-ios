//
//  FTTrackDataManger.m
//  FTMacOSSDK
//
//  Created by 胡蕾蕾 on 2021/8/4.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import "FTTrackDataManager.h"
#import "FTRecordModel.h"
#import "FTReachability.h"
#import "FTTrackerEventDBTool.h"
#import "FTInternalLog.h"
#import "FTRequest.h"
#import "FTNetworkManager.h"
#import "FTAppLifeCycle.h"
#import "FTConstants.h"
static const NSUInteger kOnceUploadDefaultCount = 10; // 一次上传数据数量

@interface FTTrackDataManager ()<FTAppLifeCycleDelegate>
@property (atomic, assign) BOOL isUploading;
@property (nonatomic, strong) NSDate *lastAddDBDate;
@property (nonatomic, strong) dispatch_queue_t serialQueue;
@end
@implementation FTTrackDataManager{
}
+(instancetype)sharedInstance{
    static  FTTrackDataManager *sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[super allocWithZone:nil] init];
    });
    return sharedInstance;
}
-(instancetype)init{
    self = [super init];
    if (self) {
        NSString *serialLabel = @"com.guance.network";
        _serialQueue = dispatch_queue_create_with_target([serialLabel UTF8String], DISPATCH_QUEUE_SERIAL, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
        [self listenNetworkChangeAndAppLifeCycle];
    }
    return self;
}
//监听网络状态 网络连接成功 触发一次上传操作
- (void)listenNetworkChangeAndAppLifeCycle{
    [[FTReachability sharedInstance] startNotifier];
    __weak typeof(self) weakSelf = self;
    [FTReachability sharedInstance].networkChanged = ^(){
        if([FTReachability sharedInstance].isReachable){
            [weakSelf uploadTrackData];
        }
    };
    [[FTAppLifeCycle sharedInstance] addAppLifecycleDelegate:self];
}
-(void)applicationDidBecomeActive{
    @try {
        [self uploadTrackData];
    }
    @catch (NSException *exception) {
        FTInnerLogError(@"exception %@",exception);
    }
}
-(void)applicationWillResignActive{
    @try {
       [[FTTrackerEventDBTool sharedManger] insertCacheToDB];
    }
    @catch (NSException *exception) {
        FTInnerLogError(@"applicationWillResignActive exception %@",exception);
    }
}
-(void)applicationWillTerminate{
    @try {
        [[FTTrackerEventDBTool sharedManger] insertCacheToDB];
    } @catch (NSException *exception) {
        FTInnerLogError(@"exception %@",exception);
    }
}
- (void)addTrackData:(FTRecordModel *)data type:(FTAddDataType)type{
    //数据写入不用做额外的线程处理，数据采集组合除了崩溃数据，都是在子线程进行的
    switch (type) {
        case FTAddDataNormal:
            [[FTTrackerEventDBTool sharedManger] insertItem:data];

            break;
        case FTAddDataLogging:{
            [[FTTrackerEventDBTool sharedManger] insertLoggingItems:data];
        }
            
            break;
        case FTAddDataImmediate:
            [[FTTrackerEventDBTool sharedManger] insertCacheToDB];
            [[FTTrackerEventDBTool sharedManger] insertItem:data];
            break;
    }
    if (self.lastAddDBDate) {
        NSDate *now = [NSDate date];
        NSTimeInterval time = [now timeIntervalSinceDate:self.lastAddDBDate];
        if (time>10) {
            self.lastAddDBDate = [NSDate date];
            [self uploadTrackData];
        }
    }else{
        self.lastAddDBDate = [NSDate date];
    }
}

- (void)uploadTrackData{
    //无网 返回
    if(![FTReachability sharedInstance].isReachable){
        return;
    }
    [self privateUpload];
}
- (void)privateUpload{
    @try {
        dispatch_async(self.serialQueue, ^{
            if (self.isUploading) {
                return;
            }
            self.isUploading = YES;
            [self flushWithType:FT_DATA_TYPE_RUM];
            [self flushWithType:FT_DATA_TYPE_LOGGING];
            
            self.isUploading = NO;
        });
    } @catch (NSException *exception) {
        FTInnerLogError(@"[NETWORK] 执行上传操作失败 %@",exception);
    }
}
-(BOOL)flushWithType:(NSString *)type{
    @autoreleasepool {
        NSArray *events = [[FTTrackerEventDBTool sharedManger] getFirstRecords:kOnceUploadDefaultCount withType:type];
        if (events.count == 0 || ![self flushWithEvents:events type:type]) {
            return NO;
        }
        FTRecordModel *model = [events lastObject];
        if (![[FTTrackerEventDBTool sharedManger] deleteItemWithType:type identify:model._id]) {
            FTInnerLogError(@"数据库删除已上传数据失败");
            return NO;
        }
    }
    return [self flushWithType:type];
}
-(BOOL)flushWithEvents:(NSArray *)events type:(NSString *)type{
    @try {
        FTInnerLogDebug(@"[NETWORK][%@] 开始上报事件(本次上报事件数:%lu)", type,(unsigned long)[events count]);
        __block BOOL success = NO;
        dispatch_semaphore_t  flushSemaphore = dispatch_semaphore_create(0);
        FTRequest *request = [FTRequest createRequestWithEvents:events type:type];
      
        [[FTNetworkManager sharedInstance] sendRequest:request completion:^(NSHTTPURLResponse * _Nonnull httpResponse, NSData * _Nullable data, NSError * _Nullable error) {
            if (error || ![httpResponse isKindOfClass:[NSHTTPURLResponse class]]) {
                FTInnerLogError(@"[NETWORK] %@", [NSString stringWithFormat:@"Network failure: %@", error ? error : @"Request 初始化失败，请检查数据上报地址是否正确"]);
                success = NO;
                dispatch_semaphore_signal(flushSemaphore);
                return;
            }
            NSInteger statusCode = httpResponse.statusCode;
            success = (statusCode >=200 && statusCode < 500);
            FTInnerLogDebug(@"[NETWORK] Upload Response statusCode : %ld",(long)statusCode);
            if (!success) {
                FTInnerLogError(@"[NETWORK] 服务器异常 稍后再试 response = %@",httpResponse);
            }
            dispatch_semaphore_signal(flushSemaphore);
        }];
        dispatch_semaphore_wait(flushSemaphore, DISPATCH_TIME_FOREVER);
        return success;
    }  @catch (NSException *exception) {
        FTInnerLogError(@"[NETWORK] exception %@",exception);
    }

    return NO;
}
@end
