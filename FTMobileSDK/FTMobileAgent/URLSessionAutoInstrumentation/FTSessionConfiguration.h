//
//  FTSessionConfiguration.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/4/21.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTSessionConfiguration : NSObject
/// 是否交换方法
@property (nonatomic,assign) BOOL isExchanged;

+ (FTSessionConfiguration *)defaultConfiguration;
/// 交换掉NSURLSessionConfiguration的 protocolClasses方法
- (void)load;
/// 还原初始化
- (void)unload;
@end

NS_ASSUME_NONNULL_END
