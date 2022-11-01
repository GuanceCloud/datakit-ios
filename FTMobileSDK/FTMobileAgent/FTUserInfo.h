//
//  FTUserInfo.h
//  FTMobileAgent
//
//  Created by hulilei on 2022/8/8.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 用户信息
///
/// 保留字段userid、user_name、user_email
@interface FTUserInfo : NSObject
/// 用户ID
@property (nonatomic, copy, readonly) NSString *userId;
/// 用户名称
@property (nonatomic, copy, readonly) NSString *name;
/// 用户邮箱
@property (nonatomic, copy, readonly) NSString *email;
/// 额外信息
@property (nonatomic, strong, readonly) NSDictionary *extra;
/// 是否设置用户信息
@property (nonatomic, assign, readonly) BOOL isSignin;

/// 更新本地保存的用户信息
/// - Parameters:
///   - Id:  ID
///   - name:  名称
///   - email: 邮箱
///   - extra: 额外信息
-(void)updateUser:(NSString *)Id name:(nullable NSString *)name email:(nullable NSString *)email extra:(nullable NSDictionary *)extra;

/// 清除本地保存的用户信息
-(void)clearUser;
@end

NS_ASSUME_NONNULL_END
