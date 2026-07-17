//
//  FTModelHelper.h
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2022/4/14.
//  Copyright 2022 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import <Foundation/Foundation.h>
#import <FTRecordModel.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTModelHelper : NSObject
+ (FTRecordModel *)createLogModel;
+ (FTRecordModel *)createLogModel:(NSString *)message;
+ (FTRecordModel *)createRumModel;
+ (FTRecordModel *)createRUMModel:(NSString *)message;
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
+ (void)addActionWithContext:(nullable NSDictionary *)context;
+ (void)resolveModelArray:(NSArray *)modelArray callBack:(void(^)(NSString *source,NSDictionary *tags,NSDictionary *fields,BOOL *stop))callBack;
+ (void)resolveModelArray:(NSArray *)modelArray idxCallBack:(void(^)(NSString *source,NSDictionary *tags,NSDictionary *fields,BOOL *stop,NSUInteger idx))callBack;
+ (void)resolveModelArray:(NSArray *)modelArray modelIdCallBack:(void(^)(NSString *source,NSDictionary *tags,NSDictionary *fields,BOOL *stop,NSString *modelId))callBack;
+ (void)resolveModelArray:(NSArray *)modelArray timeCallBack:(void(^)(NSString *source,NSDictionary *tags,NSDictionary *fields,long long time,BOOL *stop))callBack;
+ (void)resolveModelArray:(NSArray *)modelArray dataTypeCallBack:(void(^)(NSString *source,NSDictionary *tags,NSDictionary *fields,NSString *type,BOOL *stop))callBack;
@end

NS_ASSUME_NONNULL_END
