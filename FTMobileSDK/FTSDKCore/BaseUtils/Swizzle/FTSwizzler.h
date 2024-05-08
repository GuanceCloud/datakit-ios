//
//  FTSwizzler.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/7/2.
//  Copyright © 2021 hll. All rights reserved.
//

#import <Foundation/Foundation.h>

#pragma mark - Macros Based API

/// A macro for wrapping the return type of the swizzled method.
#define FTSWReturnType(type) type

/// A macro for wrapping arguments of the swizzled method.
#define FTSWArguments(arguments...) _FTSWArguments(arguments)

/// A macro for wrapping the replacement code for the swizzled method.
#define FTSWReplacement(code...) code

/// A macro for casting and calling original implementation.
/// May be used only in FTSwizzleInstanceMethod or FTSwizzlerClassMethod macros.
#define FTSWCallOriginal(arguments...) _FTSWCallOriginal(arguments)

#pragma mark └ Swizzle Instance Method

/**
 Swizzles the instance method of the class with the new implementation.

 Example for swizzling `-(int)calculate:(int)number;` method:

 @code

    FTSwizzlerInstanceMethod(classToSwizzle,
                            @selector(calculate:),
                            FTSWReturnType(int),
                            FTSWArguments(int number),
                            FTSWReplacement(
    {
        // Calling original implementation.
        int res = FTSWCallOriginal(number);
        // Returning modified return value.
        return res + 1;
    }), 0, NULL);
 
 @endcode
 
 Swizzling frequently goes along with checking whether this particular class (or one of its superclasses) has been already swizzled. Here the `FTSwizzlerMode` and `key` parameters can help. See +[FTSwizzler swizzleInstanceMethod:inClass:newImpFactory:mode:key:] for details.

 Swizzling is fully thread-safe.

 @param classToSwizzle The class with the method that should be swizzled.

 @param selector Selector of the method that should be swizzled.
 
 @param FTSWReturnType The return type of the swizzled method wrapped in the FTSWReturnType macro.
 
 @param FTSWArguments The arguments of the swizzled method wrapped in the FTSWArguments macro.
 
 @param FTSWReplacement The code of the new implementation of the swizzled method wrapped in the FTSWReplacement macro.
 
 @param FTSwizzlerMode The mode is used in combination with the key to indicate whether the swizzling should be done for the given class. You can pass 0 for FTSwizzlerModeAlways.
 
 @param key The key is used in combination with the mode to indicate whether the swizzling should be done for the given class. May be NULL if the mode is FTSwizzlerModeAlways.

 @return YES if successfully swizzled and NO if swizzling has been already done for given key and class (or one of superclasses, depends on the mode).

 */
#define FTSwizzlerInstanceMethod(classToSwizzle, \
                                selector, \
                                FTSWReturnType, \
                                FTSWArguments, \
                                FTSWReplacement, \
                                FTSwizzlerMode, \
                                key) \
    _FTSwizzlerInstanceMethod(classToSwizzle, \
                             selector, \
                             FTSWReturnType, \
                             _FTSWWrapArg(FTSWArguments), \
                             _FTSWWrapArg(FTSWReplacement), \
                             FTSwizzlerMode, \
                             key)

#pragma mark └ Swizzle Class Method

/**
 Swizzles the class method of the class with the new implementation.

 Example for swizzling `+(int)calculate:(int)number;` method:

 @code

    FTSwizzlerClassMethod(classToSwizzle,
                         @selector(calculate:),
                         FTSWReturnType(int),
                         FTSWArguments(int number),
                         FTSWReplacement(
    {
        // Calling original implementation.
        int res = FTSWCallOriginal(number);
        // Returning modified return value.
        return res + 1;
    }));
 
 @endcode

 Swizzling is fully thread-safe.

 @param classToSwizzle The class with the method that should be swizzled.

 @param selector Selector of the method that should be swizzled.
 
 @param FTSWReturnType The return type of the swizzled method wrapped in the FTSWReturnType macro.
 
 @param FTSWArguments The arguments of the swizzled method wrapped in the FTSWArguments macro.
 
 @param FTSWReplacement The code of the new implementation of the swizzled method wrapped in the FTSWReplacement macro.
 
 */
#define FTSwizzlerClassMethod(classToSwizzle, \
                             selector, \
                             FTSWReturnType, \
                             FTSWArguments, \
                             FTSWReplacement) \
    _FTSwizzlerClassMethod(classToSwizzle, \
                          selector, \
                          FTSWReturnType, \
                          _FTSWWrapArg(FTSWArguments), \
                          _FTSWWrapArg(FTSWReplacement))

#pragma mark - Main API

/**
 A function pointer to the original implementation of the swizzled method.
 */
typedef void (*FTSwizzlerOriginalIMP)(void /* id, SEL, ... */ );

/**
 FTSwizzlerInfo is used in the new implementation block to get and call original implementation of the swizzled method.
 */
@interface FTSwizzlerInfo : NSObject

/**
 Returns the original implementation of the swizzled method.

 It is actually either an original implementation if the swizzled class implements the method itself; or a super implementation fetched from one of the superclasses.
 
 @note You must always cast returned implementation to the appropriate function pointer when calling.
 
 @return A function pointer to the original implementation of the swizzled method.
 */
-(FTSwizzlerOriginalIMP)getOriginalImplementation;

/// The selector of the swizzled method.
@property (nonatomic, readonly) SEL selector;

@end

/**
 A factory block returning the block for the new implementation of the swizzled method.

 You must always obtain original implementation with swizzleInfo and call it from the new implementation.
 
 @param swizzleInfo An info used to get and call the original implementation of the swizzled method.

 @return A block that implements a method.
    Its signature should be: `method_return_type ^(id self, method_args...)`.
    The selector is not available as a parameter to this block.
 */
typedef id (^FTSwizzlerImpFactoryBlock)(FTSwizzlerInfo *swizzleInfo);

typedef NS_ENUM(NSUInteger, FTSwizzlerMode) {
    /// FTSwizzler always does swizzling.
    FTSwizzlerModeAlways = 0,
    /// FTSwizzler does not do swizzling if the same class has been swizzled earlier with the same key.
    FTSwizzlerModeOncePerClass = 1,
    /// FTSwizzler does not do swizzling if the same class or one of its superclasses have been swizzled earlier with the same key.
    /// @note There is no guarantee that your implementation will be called only once per method call. If the order of swizzling is: first inherited class, second superclass, then both swizzlings will be done and the new implementation will be called twice.
    FTSwizzlerModeOncePerClassAndSuperclasses = 2
};

@interface FTSwizzler : NSObject

#pragma mark └ Swizzle Instance Method

/**
 Swizzles the instance method of the class with the new implementation.

 Original implementation must always be called from the new implementation. And because of the the fact that for safe and robust swizzling original implementation must be dynamically fetched at the time of calling and not at the time of swizzling, swizzling API is a little bit complicated.

 You should pass a factory block that returns the block for the new implementation of the swizzled method. And use swizzleInfo argument to retrieve and call original implementation.

 Example for swizzling `-(int)calculate:(int)number;` method:
 
 @code

    SEL selector = @selector(calculate:);
    [FTSwizzler
     swizzleInstanceMethod:selector
     inClass:classToSwizzle
     newImpFactory:^id(FTSwizzlerInfo *swizzleInfo) {
         // This block will be used as the new implementation.
         return ^int(__unsafe_unretained id self, int num){
             // You MUST always cast implementation to the correct function pointer.
             int (*originalIMP)(__unsafe_unretained id, SEL, int);
             originalIMP = (__typeof(originalIMP))[swizzleInfo getOriginalImplementation];
             // Calling original implementation.
             int res = originalIMP(self,selector,num);
             // Returning modified return value.
             return res + 1;
         };
     }
     mode:FTSwizzlerModeAlways
     key:NULL];
 
 @endcode

 Swizzling frequently goes along with checking whether this particular class (or one of its superclasses) has been already swizzled. Here the `mode` and `key` parameters can help.

 Here is an example of swizzling `-(void)dealloc;` only in case when neither class and no one of its superclasses has been already swizzled with our key. However "Deallocating ..." message still may be logged multiple times per method call if swizzling was called primarily for an inherited class and later for one of its superclasses.
 
 @code
 
    static const void *key = &key;
    SEL selector = NSSelectorFromString(@"dealloc");
    [FTSwizzler
     swizzleInstanceMethod:selector
     inClass:classToSwizzle
     newImpFactory:^id(FTSwizzlerInfo *swizzleInfo) {
         return ^void(__unsafe_unretained id self){
             NSLog(@"Deallocating %@.",self);
             
             void (*originalIMP)(__unsafe_unretained id, SEL);
             originalIMP = (__typeof(originalIMP))[swizzleInfo getOriginalImplementation];
             originalIMP(self,selector);
         };
     }
     mode:FTSwizzlerModeOncePerClassAndSuperclasses
     key:key];
 
 @endcode

 Swizzling is fully thread-safe.
 
 @param selector Selector of the method that should be swizzled.

 @param classToSwizzle The class with the method that should be swizzled.
 
 @param factoryBlock The factory block returning the block for the new implementation of the swizzled method.
 
 @param mode The mode is used in combination with the key to indicate whether the swizzling should be done for the given class.
 
 @param key The key is used in combination with the mode to indicate whether the swizzling should be done for the given class. May be NULL if the mode is FTSwizzlerModeAlways.

 @return YES if successfully swizzled and NO if swizzling has been already done for given key and class (or one of superclasses, depends on the mode).
 */
+(BOOL)swizzleInstanceMethod:(SEL)selector
                     inClass:(Class)classToSwizzle
               newImpFactory:(FTSwizzlerImpFactoryBlock)factoryBlock
                        mode:(FTSwizzlerMode)mode
                         key:(const void *)key;

#pragma mark └ Swizzle Class method

/**
 Swizzles the class method of the class with the new implementation.

 Original implementation must always be called from the new implementation. And because of the the fact that for safe and robust swizzling original implementation must be dynamically fetched at the time of calling and not at the time of swizzling, swizzling API is a little bit complicated.

 You should pass a factory block that returns the block for the new implementation of the swizzled method. And use swizzleInfo argument to retrieve and call original implementation.

 Example for swizzling `+(int)calculate:(int)number;` method:
 
 @code

    SEL selector = @selector(calculate:);
    [FTSwizzler
     swizzleClassMethod:selector
     inClass:classToSwizzle
     newImpFactory:^id(FTSwizzlerInfo *swizzleInfo) {
         // This block will be used as the new implementation.
         return ^int(__unsafe_unretained id self, int num){
             // You MUST always cast implementation to the correct function pointer.
             int (*originalIMP)(__unsafe_unretained id, SEL, int);
             originalIMP = (__typeof(originalIMP))[swizzleInfo getOriginalImplementation];
             // Calling original implementation.
             int res = originalIMP(self,selector,num);
             // Returning modified return value.
             return res + 1;
         };
     }];
 
 @endcode

 Swizzling is fully thread-safe.
 
 @param selector Selector of the method that should be swizzled.

 @param classToSwizzle The class with the method that should be swizzled.
 
 @param factoryBlock The factory block returning the block for the new implementation of the swizzled method.
 */
+(void)swizzleClassMethod:(SEL)selector
                  inClass:(Class)classToSwizzle
            newImpFactory:(FTSwizzlerImpFactoryBlock)factoryBlock;

// setDelegate时，返回正确的delegate
+ (Class)realDelegateClassFromSelector:(SEL)selector proxy:(id)proxy;
+ (BOOL)realDelegateClass:(Class)cls respondsToSelector:(SEL)sel;

@end

#pragma mark - Implementation details
// Do not write code that depends on anything below this line.

// Wrapping arguments to pass them as a single argument to another macro.
#define _FTSWWrapArg(args...) args

#define _FTSWDel2Arg(a1, a2, args...) a1, ##args
#define _FTSWDel3Arg(a1, a2, a3, args...) a1, a2, ##args

// To prevent comma issues if there are no arguments we add one dummy argument
// and remove it later.
#define _FTSWArguments(arguments...) DEL, ##arguments

#define _FTSwizzlerInstanceMethod(classToSwizzle, \
                                 selector, \
                                 FTSWReturnType, \
                                 FTSWArguments, \
                                 FTSWReplacement, \
                                 FTSwizzlerMode, \
                                 KEY) \
    [FTSwizzler \
     swizzleInstanceMethod:selector \
     inClass:[classToSwizzle class] \
     newImpFactory:^id(FTSwizzlerInfo *swizzleInfo) { \
        FTSWReturnType (*originalImplementation_)(_FTSWDel3Arg(__unsafe_unretained id, \
                                                               SEL, \
                                                               FTSWArguments)); \
        SEL selector_ = selector; \
        return ^FTSWReturnType (_FTSWDel2Arg(__unsafe_unretained id self, \
                                             FTSWArguments)) \
        { \
            FTSWReplacement \
        }; \
     } \
     mode:FTSwizzlerMode \
     key:KEY];

#define _FTSwizzlerClassMethod(classToSwizzle, \
                              selector, \
                              FTSWReturnType, \
                              FTSWArguments, \
                              FTSWReplacement) \
    [FTSwizzler \
     swizzleClassMethod:selector \
     inClass:[classToSwizzle class] \
     newImpFactory:^id(FTSwizzlerInfo *swizzleInfo) { \
        FTSWReturnType (*originalImplementation_)(_FTSWDel3Arg(__unsafe_unretained id, \
                                                               SEL, \
                                                               FTSWArguments)); \
        SEL selector_ = selector; \
        return ^FTSWReturnType (_FTSWDel2Arg(__unsafe_unretained id self, \
                                             FTSWArguments)) \
        { \
            FTSWReplacement \
        }; \
     }];

#define _FTSWCallOriginal(arguments...) \
    ((__typeof(originalImplementation_))[swizzleInfo \
                                         getOriginalImplementation])(self, \
                                                                     selector_, \
                                                                     ##arguments)
