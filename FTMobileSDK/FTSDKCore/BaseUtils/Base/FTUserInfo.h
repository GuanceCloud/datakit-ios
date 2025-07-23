//
//  FTUserInfo.h
//  FTMobileAgent
//
//  Created by hulilei on 2022/8/8.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// User information
///
/// Reserved fields: userid, user_name, user_email
@interface FTUserInfo : NSObject<NSCopying>
/// User ID
@property (nonatomic, copy, readonly) NSString *userId;
/// User name
@property (nonatomic, copy, readonly) NSString *name;
/// User email
@property (nonatomic, copy, readonly) NSString *email;
/// Additional information
@property (nonatomic, strong, readonly) NSDictionary *extra;
/// Whether user information is set
@property (nonatomic, assign, readonly) BOOL isSignIn;

/// Update locally saved user information
/// - Parameters:
///   - Id:  ID
///   - name:  Name
///   - email: Email
///   - extra: Additional information
-(void)updateUser:(NSString *)Id name:(nullable NSString *)name email:(nullable NSString *)email extra:(nullable NSDictionary *)extra;

/// Clear locally saved user information
-(void)clearUser;
@end

NS_ASSUME_NONNULL_END
