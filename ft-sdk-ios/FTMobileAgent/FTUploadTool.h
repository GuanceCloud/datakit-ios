//
//  FTUploadTool.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2019/12/3.
//  Copyright © 2019 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
@class FTMobileConfig;
@class FTRecordModel;
NS_ASSUME_NONNULL_BEGIN

@interface FTUploadTool : NSObject
@property (nonatomic, strong) FTMobileConfig *config;
-(instancetype)initWithConfig:(FTMobileConfig *)config;
/**
 *后台存储的数据启动上传流程
*/
-(void)upload;
/**
 *立即上传 单条数据
*/
-(void)trackImmediate:(FTRecordModel *)model callBack:(void (^)(NSInteger statusCode, NSData *response))callBack;
/**
 *立即上传 多条数据
*/
-(void)trackImmediateList:(NSArray <FTRecordModel *>*)modelList callBack:(void (^)(NSInteger statusCode, NSData *response))callBack;

@end

NS_ASSUME_NONNULL_END
