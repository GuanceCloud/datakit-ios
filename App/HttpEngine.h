//
//  HttpEngine.h
//  App
//
//  Created by hulilei on 2022/9/26.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTURLSessionDelegate.h"
NS_ASSUME_NONNULL_BEGIN
/**
 * 使用 session 工具的方法
 * InstrumentationDirect 直接使用
 * InstrumentationInherit 继承使用
 * InstrumentationProperty 作为属性使用
 */
typedef NS_ENUM(NSUInteger,FTSessionInstrumentationType){
    InstrumentationDirect,
    InstrumentationInherit,
    InstrumentationProperty,
};
@interface HttpEngine : NSObject
- (instancetype)initWithSessionInstrumentationType:(FTSessionInstrumentationType)type;
- (void)network:(void (^)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler;
@end


NS_ASSUME_NONNULL_END
