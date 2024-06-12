//
//  FTSessionReplayUploader.m
//  FTMobileAgent
//
//  Created by hulilei on 2023/1/11.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import "FTSessionReplayUploader.h"
#import "FTCompression.h"
#import "FTLog+Private.h"
#import "FTNetworkManager.h"
#import "FTImageRequest.h"
#import "FTJSONUtil.h"
NSString * const FT_SESSION_REPLAY_INFO_PLIST = @"snapshot.plist";

@interface FTSessionReplayUploader()
@property (atomic, assign) BOOL uploading; //使用atomic锁
@property (nonatomic, copy) NSString *basePath;
@property (nonatomic, strong) FTCompression *compression;
@property (nonatomic, strong) FTNetworkManager *networkManager;
@property (nonatomic, strong) dispatch_queue_t serialQueue;
@end
@implementation FTSessionReplayUploader
-(instancetype)init{
    self = [super init];
    if(self){
        _basePath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"snapshot"];
        NSString *serialLabel = [NSString stringWithFormat:@"ft.snapshotUpload.%p", self];
        _serialQueue = dispatch_queue_create([serialLabel UTF8String], DISPATCH_QUEUE_SERIAL);
        _onceUploadCount = 20;
        _uploading = NO;
        _compression = [[FTCompression alloc]init];
    }
    return self;
}
-(void)flushSessionReplay{
    dispatch_async(self.serialQueue, ^{
        if(self.uploading){
            return;
        }
        self.uploading = YES;
        // 具体的上传
        NSError *error;
        NSArray *array = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.basePath error:&error];
        NSEnumerator *enumerator = [array objectEnumerator];
        NSString *filePath;
        while ((filePath = enumerator.nextObject) != nil) {
            NSString *name = [filePath lastPathComponent];
            if(name!=self.currentViewid){
                [self flushSessionReplay:name];
            }
        }
        self.uploading = NO;
    });
}
-(void)flushSessionReplay:(NSString *)viewid{
    NSString *filePath =[self.basePath stringByAppendingPathComponent:viewid];
    NSError *error;
    NSMutableArray *array = [[[NSFileManager defaultManager] contentsOfDirectoryAtPath:filePath error:&error] mutableCopy];
    [array removeObject:FT_SESSION_REPLAY_INFO_PLIST];
    if(array.count == 0){
        //有一些容器类型控制器如UINavigationController、UITabBarController ，rum view层面会有进入进出，但实际上会立即被内容页面挤出，所以没有实际的截图文件
        [[NSFileManager defaultManager] removeItemAtPath:filePath error:&error];
        return;
    }
    NSArray *result = [array sortedArrayUsingComparator:^NSComparisonResult(id _Nonnull obj1, id _Nonnull obj2) {
        return [obj1 compare:obj2]; // 升序
    }];
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:[filePath stringByAppendingPathComponent:FT_SESSION_REPLAY_INFO_PLIST]];
    if(dict == nil){
        return;
    }
    NSInteger lastCount = result.count%self.onceUploadCount;
    NSInteger times = lastCount==0?result.count/self.onceUploadCount:(result.count/self.onceUploadCount)+1;
    for (NSInteger i=0; i<times; i++) {
        NSString *zipPath = [self.basePath stringByAppendingFormat:@"/%@.zip",[[NSUUID UUID] UUIDString]];
        NSMutableArray *files = [[NSMutableArray alloc]init];
        NSUInteger len = self.onceUploadCount;
        if(i+1==times){
            len = lastCount==0?self.onceUploadCount:lastCount;
        }
        NSArray *subArray = [result subarrayWithRange:NSMakeRange(i*self.onceUploadCount, len)];
        for (NSString *name in subArray) {
            [files addObject:[filePath stringByAppendingPathComponent:name]];
        }
        NSMutableDictionary *param = [NSMutableDictionary dictionaryWithDictionary:self.baseProperty];
        [param setValue:[result firstObject] forKey:@"start"];
        [param setValue:[result lastObject] forKey:@"end"];
        [param setValue:@(result.count) forKey:@"records_count"];
        [param setValue:@"ios" forKey:@"source"];
        [param addEntriesFromDictionary:dict];
        [param setValue:viewid forKey:@"view_id"];
        if([self flushWithFiles:@[zipPath] parameters:param]){
            // 删除 zip 文件
            [[NSFileManager defaultManager] removeItemAtPath:zipPath error:&error];
            if(i+1==times){
                // 如果该文件夹下所有图片全部上传，整个文件夹删除
                [[NSFileManager defaultManager] removeItemAtPath:filePath error:&error];
            }else{
                // 如果该文件夹只上传了部分，删除已上传图片
                for (NSString *parh in subArray) {
                    [[NSFileManager defaultManager] removeItemAtPath:parh error:&error];
                }
            }
        }else{
            //上传失败
            FTInnerLogError(@"Fail To Upload Session Replay Images ");
            break;
        }
    }
}
-(BOOL)flushWithFiles:(NSArray *)files parameters:(NSDictionary *)parameters{
    @try {
        FTInnerLogDebug(@"-----开始上传 session replay-----");
        __block BOOL success = NO;
        dispatch_semaphore_t  flushSemaphore = dispatch_semaphore_create(0);
        FTRequest *request = [[FTImageRequest alloc]initRequestWithFiles:files parameters:parameters];
      
        [self.networkManager sendRequest:request completion:^(NSHTTPURLResponse * _Nonnull httpResponse, NSData * _Nullable data, NSError * _Nullable error) {
            if (error || ![httpResponse isKindOfClass:[NSHTTPURLResponse class]]) {
                FTInnerLogError(@"%@", [NSString stringWithFormat:@"Network failure: %@", error ? error : @"Unknown error"]);
                success = NO;
                dispatch_semaphore_signal(flushSemaphore);
                return;
            }
            NSInteger statusCode = httpResponse.statusCode;
            success = (statusCode >=200 && statusCode < 500);
            FTInnerLogDebug(@"[NETWORK] Upload Response statusCode : %ld",(long)statusCode);
            if (statusCode != 200 && data.length>0) {
                FTInnerLogError(@"[NETWORK] 服务器异常 稍后再试 responseData = %@",[FTJSONUtil dictionaryWithJsonString:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]]);
            }
            dispatch_semaphore_signal(flushSemaphore);
        }];
        dispatch_semaphore_wait(flushSemaphore, DISPATCH_TIME_FOREVER);
        return success;
    }  @catch (NSException *exception) {
        FTInnerLogError(@"exception %@",exception);
    }

    return NO;
}
@end
