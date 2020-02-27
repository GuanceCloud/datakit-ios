//
//  TestAccount.h
//  ft-sdk-iosTest
//
//  Created by 胡蕾蕾 on 2020/2/27.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TestAccount : NSObject
@property (nonatomic, copy) NSString *ftTestAccount;
@property (nonatomic, copy) NSString *ftTestPassword;

@property (nonatomic, copy) NSString *accessKeyID;
@property (nonatomic, copy) NSString *accessKeySecret;
@property (nonatomic, copy) NSString *accessServerUrl;

@end

NS_ASSUME_NONNULL_END
