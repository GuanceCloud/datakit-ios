//
//  FTRecordModel.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2019/11/28.
//  Copyright © 2019 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface FTRecordModel : NSObject

@property (nonatomic, assign) long long tm;
//记录的操作数数据
@property (nonatomic, strong) NSString *data;
//上传时的API类型
@property (nonatomic, strong) NSString *op;

-(instancetype)initWithSource:(NSString *)source op:(NSString *)op tags:(NSDictionary *)tags field:(NSDictionary *)field tm:(long long)tm;
@end

NS_ASSUME_NONNULL_END
