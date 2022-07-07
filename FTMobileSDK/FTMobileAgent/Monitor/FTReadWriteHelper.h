//
//  FTReadWriteHelper.h
//  FTMobileAgent
//
//  Created by hulilei on 2022/7/7.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTReadWriteHelper<ValueType> : NSObject
-(instancetype)initWithValue:(ValueType)value;
@end

NS_ASSUME_NONNULL_END
