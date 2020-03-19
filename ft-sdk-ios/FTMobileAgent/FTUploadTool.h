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
-(instancetype)initWithConfig:(FTMobileConfig *)config;
-(void)upload;
-(void)trackImmediate:(FTRecordModel *)model callBack:(void (^)(NSInteger statusCode, id responseObject))callBack;
-(void)trackImmediateList:(NSArray <FTRecordModel *>*)modelList callBack:(void (^)(NSInteger statusCode, id responseObject))callBack;

@end

NS_ASSUME_NONNULL_END
