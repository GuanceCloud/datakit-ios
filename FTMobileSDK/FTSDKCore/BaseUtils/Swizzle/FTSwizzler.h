//
//  FTSwizzler.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/7/2.
//  Copyright © 2021 hll. All rights reserved.
//

#import <Foundation/Foundation.h>

#define MAPTABLE_ID(x) (__bridge id)((void *)x)

// Ignore the warning cause we need the paramters to be dynamic and it's only being used internally
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wstrict-prototypes"
typedef void (^datafluxSwizzleBlock)();
#pragma clang diagnostic pop
/// 方法调配工具
///
/// 使用注意事项：判断参数是否为基本常量，若为则可能需要自行添加替换方法
@interface FTSwizzler : NSObject

/// 方法调配
/// - Parameters:
///   - aSelector: 想要 hook 的方法
///   - aClass: 方法的类
///   - block: hook 方法后自己想要执行的代码块
///   - aName: 标记
+ (void)swizzleSelector:(SEL)aSelector onClass:(Class)aClass withBlock:(datafluxSwizzleBlock)block named:(NSString *)aName;
/// 取消方法调配
/// - Parameters:
///   - aSelector: hook 的方法
///   - aClass: 方法的类
+ (void)unswizzleSelector:(SEL)aSelector onClass:(Class)aClass;
/// 根据标记取消方法的调配，针对该方法的其他调配继续生效
/// - Parameters:
///   - aSelector: hook 的方法
///   - aClass: 方法的类
///   - aName: 标记
+ (void)unswizzleSelector:(SEL)aSelector onClass:(Class)aClass named:(NSString *)aName;
+ (void)printSwizzles;
+ (BOOL)realDelegateClass:(Class)cls respondsToSelector:(SEL)sel;
+ (Class)realDelegateClassFromSelector:(SEL)selector proxy:(id)proxy;
@end
