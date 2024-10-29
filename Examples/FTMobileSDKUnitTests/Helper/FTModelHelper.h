//
//  FTModelHelper.h
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2022/4/14.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <FTRecordModel.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTModelHelper : NSObject
+ (FTRecordModel *)createLogModel;
+ (FTRecordModel *)createLogModel:(NSString *)message;
+ (FTRecordModel *)createRumModel;
+ (FTRecordModel *)createWrongFormatRumModel;
+ (void)startView;
+ (void)startViewWithName:(NSString *)name;
+ (void)startView:(NSDictionary *)context;
+ (void)stopView;
+ (void)stopView:(NSDictionary *)context;
+ (void)startResource:(NSString *)key;
+ (void)stopErrorResource:(NSString *)key;
+ (void)startAction;
+ (void)startActionWithType:(NSString *)type;
+ (void)startActionWithContext:(NSDictionary *)context;
+ (void)resolveModelArray:(NSArray *)modelArray callBack:(void(^)(NSString *source,NSDictionary *tags,NSDictionary *fields,BOOL *stop))callBack;
+ (void)resolveModelArray:(NSArray *)modelArray idxCallBack:(void(^)(NSString *source,NSDictionary *tags,NSDictionary *fields,BOOL *stop,NSUInteger idx))callBack;
+ (void)resolveModelArray:(NSArray *)modelArray modelIdCallBack:(void(^)(NSString *source,NSDictionary *tags,NSDictionary *fields,BOOL *stop,NSString *modelId))callBack;
+ (void)resolveModelArray:(NSArray *)modelArray timeCallBack:(void(^)(NSString *source,NSDictionary *tags,NSDictionary *fields,long long time,BOOL *stop))callBack;
@end

NS_ASSUME_NONNULL_END
