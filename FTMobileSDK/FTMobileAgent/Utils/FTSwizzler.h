//
//  FTSwizzler.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/7/2.
//  Copyright © 2021 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
typedef NS_OPTIONS(NSUInteger, FTSwizzleOptions) {
    FTSwizzlePositionAfter   = 0,
    FTSwizzlePositionBefore = 1,
};
#define FTSwizzleClassMethod(classToSwizzle, \
                             selector, \
                             RSSWReturnType, \
                             RSSWArguments, \
                             RSSWReplacement) \
    _RSSwizzleClassMethod(classToSwizzle, \
                          selector, \
                          RSSWReturnType, \
                          _RSSWWrapArg(RSSWArguments), \
                          _RSSWWrapArg(RSSWReplacement))
typedef void (*FTSwizzleOriginalIMP)(void /* id, SEL, ... */ );

@interface FTSwizzleInfo : NSObject

-(FTSwizzleOriginalIMP)getOriginalImplementation;

@property (nonatomic, readonly) SEL selector;

@end

typedef id (^FTSwizzleImpFactoryBlock)(FTSwizzleInfo *swizzleInfo);

@interface FTSwizzler : NSObject
+(void)swizzleInstanceMethod:(SEL)selector
                     inClass:(Class)classToSwizzle
newImpFactory:(FTSwizzleImpFactoryBlock)factoryBlock;
+ (BOOL)realDelegateClass:(Class)cls respondsToSelector:(SEL)sel;
+ (Class)realDelegateClassFromSelector:(SEL)selector proxy:(id)proxy;
@end
