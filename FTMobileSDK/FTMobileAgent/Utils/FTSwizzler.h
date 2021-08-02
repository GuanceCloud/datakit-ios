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

@interface FTSwizzler : NSObject

+ (void)swizzleSelector:(SEL)aSelector onClass:(Class)aClass withBlock:(datafluxSwizzleBlock)block named:(NSString *)aName;
+ (void)unswizzleSelector:(SEL)aSelector onClass:(Class)aClass named:(NSString *)aName;
+ (void)printSwizzles;
+ (BOOL)realDelegateClass:(Class)cls respondsToSelector:(SEL)sel;
+ (Class)realDelegateClassFromSelector:(SEL)selector proxy:(id)proxy;
@end
