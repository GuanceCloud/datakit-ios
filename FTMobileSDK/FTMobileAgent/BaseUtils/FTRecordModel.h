//
//  FTRecordModel.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2019/11/28.
//  Copyright © 2019 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTConstants.h"
NS_ASSUME_NONNULL_BEGIN
@interface FTRecordModel : NSObject
//数据库自增id
@property (nonatomic, assign) long _id;
@property (nonatomic, assign) long long tm;
//用于区分该数据绑定的userdata
@property (nonatomic, strong) NSString *sessionid;
//记录的操作数数据
@property (nonatomic, strong) NSString *data;
//从数据库读取数据时拼接的用户信息
@property (nonatomic, strong) NSString *userdata;
//上传时的API类型
@property (nonatomic, strong) NSString *op;

-(instancetype)initWithSource:(NSString *)source op:(FTDataType )op tags:(NSDictionary *)tags field:(NSDictionary *)field tm:(long long)tm;
@end

NS_ASSUME_NONNULL_END
