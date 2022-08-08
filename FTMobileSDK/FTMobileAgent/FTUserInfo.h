//
//  FTUserInfo.h
//  FTMobileAgent
//
//  Created by hulilei on 2022/8/8.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTUserInfo : NSObject
@property (nonatomic, copy, readonly) NSString *userId;
@property (nonatomic, copy, readonly) NSString *name;
@property (nonatomic, strong, readonly) NSDictionary *extra;
@property (nonatomic, assign, readonly) BOOL isSignin;
-(void)updateUser:(NSString *)Id name:(nullable NSString *)name extra:(nullable NSDictionary *)extra;
-(void)clearUser;
@end

NS_ASSUME_NONNULL_END
