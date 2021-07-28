//
//  NSObject+FTAutoTrack.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/7/28.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSObject (FTAutoTrack)
/// 用于记录创建子类时的原始父类名称
@property (nonatomic, copy, nullable) NSString *dataFlux_className;
@end

NS_ASSUME_NONNULL_END
