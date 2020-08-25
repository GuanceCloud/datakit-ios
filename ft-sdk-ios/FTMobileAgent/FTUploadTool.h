//
//  FTUploadTool.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2019/12/3.
//  Copyright © 2019 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
@class FTMobileConfig;
@class FTRecordModel;

NS_ASSUME_NONNULL_BEGIN
typedef void(^FTURLTaskCompletionHandler)(NSInteger  statusCode, NSData * _Nullable response);
typedef void(^FTURLSessionTaskCompletionHandler)(NSData * _Nullable data, NSHTTPURLResponse * _Nullable response, NSError * _Nullable error);


@interface FTUploadTool : NSObject
@property (nonatomic, strong) dispatch_queue_t serialQueue;
@property (nonatomic, strong) FTMobileConfig *config;
-(instancetype)initWithConfig:(FTMobileConfig *)config;
/**
 *后台存储的数据启动上传流程
*/
-(void)upload;
/**
 *立即上传 单条数据
*/
-(NSURLRequest *)trackImmediate:(FTRecordModel *)model callBack:(FTURLTaskCompletionHandler)callBack;
/**
 *立即上传 多条数据
*/
-(NSURLRequest *)trackImmediateList:(NSArray <FTRecordModel *>*)modelList callBack:(FTURLTaskCompletionHandler)callBack;
- (void)stopLoading;
@end

NS_ASSUME_NONNULL_END
