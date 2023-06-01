//
//  FTSwizzler.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/7/2.
//  Copyright © 2021 hll. All rights reserved.
//
#import <objc/runtime.h>
#import <objc/message.h>
#import "FTSwizzler.h"
#import "FTInternalLog.h"
#define DATAFLUX_MIN_ARGS 2
#define DATAFLUX_MAX_ARGS 5
#define FT_FIND_SWIZZLE \
FTSDKSwizzlingOnClass *swizzlingOnClass = ft_findSwizzle(self, _cmd); \
FTSwizzleEntity *swizzle = swizzlingOnClass.bindingSwizzle;

#define FT_REMOVE_SELECTOR \
[FTSwizzler object:self ofClass:swizzlingOnClass.bindingClass removeSelector:_cmd];
@interface FTSwizzleEntity : NSObject

@property (nonatomic, assign) Class class;
@property (nonatomic, assign) SEL selector;
@property (nonatomic, assign) IMP originalMethod;
@property (nonatomic, assign) uint numArgs;
@property (nonatomic, copy) NSMapTable *blocks;

- (instancetype)initWithBlock:(datafluxSwizzleBlock)aBlock
                        named:(NSString *)aName
                     forClass:(Class)aClass
                     selector:(SEL)aSelector
               originalMethod:(IMP)aMethod
                  withNumArgs:(uint)numArgs;

@end
@interface FTSDKSwizzlingOnClass : NSObject

@property (nonatomic) FTSwizzleEntity *bindingSwizzle;
@property (nonatomic) Class bindingClass;

- (instancetype)initWithSwizzle:(FTSwizzleEntity *)aSwizzle
                          class:(Class)aClass;

@end
@interface FTSwizzler ()

+ (void)object:(id)anObject ofClass:(Class)aClass addSelector:(SEL)aSelector;
+ (void)object:(id)anObject ofClass:(Class)aClass removeSelector:(SEL)aSelector;
+ (BOOL)object:(id)anObject ofClass:(Class)aClass isCallingSelector:(SEL)aSelector;

@end
static NSMapTable *datafluxSwizzles;
static NSMutableSet<NSString *> *selectorCallingSet;
static FTSDKSwizzlingOnClass *ft_findSwizzle(id self, SEL _cmd)
{
    Method aMethod = class_getInstanceMethod(object_getClass(self), _cmd);
    Class this_class = object_getClass(self);
    FTSwizzleEntity *swizzle = nil;
    
    if (![FTSwizzler object:self ofClass:this_class isCallingSelector:_cmd]) {
        swizzle = (FTSwizzleEntity *)[datafluxSwizzles objectForKey:MAPTABLE_ID(aMethod)];
    }
    
    while (!swizzle && class_getSuperclass(this_class)) {
        this_class = class_getSuperclass(this_class);
        aMethod = class_getInstanceMethod(this_class, _cmd);
        
        if (![FTSwizzler object:self ofClass:this_class isCallingSelector:_cmd]) {
            swizzle = (FTSwizzleEntity *)[datafluxSwizzles objectForKey:MAPTABLE_ID(aMethod)];
        }
    }
    
    if (swizzle) {
        [FTSwizzler object:self ofClass:this_class addSelector:_cmd];
    }
    FTSDKSwizzlingOnClass *swizzlingOnClass = [[FTSDKSwizzlingOnClass alloc] initWithSwizzle:swizzle
                                                                                       class:this_class];
    return swizzlingOnClass;
}

static void ft_swizzledMethod_2(id self, SEL _cmd)
{
    FT_FIND_SWIZZLE
    if (swizzle) {
        ((void(*)(id, SEL))swizzle.originalMethod)(self, _cmd);
        
        NSEnumerator *blocks = [swizzle.blocks objectEnumerator];
        datafluxSwizzleBlock block;
        while ((block = [blocks nextObject])) {
            block(self, _cmd);
        }
        FT_REMOVE_SELECTOR
    }
}

static void ft_swizzledMethod_3(id self, SEL _cmd, id arg)
{
    FT_FIND_SWIZZLE
    if (swizzle) {
        ((void(*)(id, SEL, id))swizzle.originalMethod)(self, _cmd, arg);
        
        NSEnumerator *blocks = [swizzle.blocks objectEnumerator];
        datafluxSwizzleBlock block;
        while ((block = [blocks nextObject])) {
            block(self, _cmd, arg);
        }
        FT_REMOVE_SELECTOR
    }
}

static void ft_swizzledMethod_4(id self, SEL _cmd, id arg, id arg2)
{
    FT_FIND_SWIZZLE
    if (swizzle) {
        ((void(*)(id, SEL, id, id))swizzle.originalMethod)(self, _cmd, arg, arg2);
        
        NSEnumerator *blocks = [swizzle.blocks objectEnumerator];
        datafluxSwizzleBlock block;
        while ((block = [blocks nextObject])) {
            block(self, _cmd, arg, arg2);
        }
        FT_REMOVE_SELECTOR
    }
}

static void ft_swizzledMethod_5(id self, SEL _cmd, id arg, id arg2, id arg3)
{
    FT_FIND_SWIZZLE
    if (swizzle) {
        ((void(*)(id, SEL, id, id, id))swizzle.originalMethod)(self, _cmd, arg, arg2, arg3);
        
        NSEnumerator *blocks = [swizzle.blocks objectEnumerator];
        datafluxSwizzleBlock block;
        while ((block = [blocks nextObject])) {
            block(self, _cmd, arg, arg2, arg3);
        }
        FT_REMOVE_SELECTOR
    }
}
static void ft_swizzleMethod_3_io(id self, SEL _cmd, BOOL arg)
{
    FT_FIND_SWIZZLE;
    if (swizzle) {
        ((void (*)(id, SEL, BOOL))swizzle.originalMethod)(self, _cmd, arg);
        
        NSEnumerator *blocks = [swizzle.blocks objectEnumerator];
        datafluxSwizzleBlock block;
        while ((block = [blocks nextObject])) {
            block(self, _cmd, arg);
        }
        FT_REMOVE_SELECTOR;
    }
}
// Ignore the warning cause we need the paramters to be dynamic and it's only being used internally
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wstrict-prototypes"
static void (*ft_swizzledMethods[DATAFLUX_MAX_ARGS - DATAFLUX_MIN_ARGS + 1])() = {ft_swizzledMethod_2, ft_swizzledMethod_3, ft_swizzledMethod_4, ft_swizzledMethod_5};
#pragma clang diagnostic pop

@implementation FTSwizzler

+ (void)initialize
{
    datafluxSwizzles = [NSMapTable mapTableWithKeyOptions:(NSPointerFunctionsOpaqueMemory | NSPointerFunctionsOpaquePersonality)
                                             valueOptions:(NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPointerPersonality)];
    selectorCallingSet = [NSMutableSet set];
    
}

+ (void)printSwizzles
{
    NSEnumerator *en = [datafluxSwizzles objectEnumerator];
    FTSwizzler *swizzle;
    while ((swizzle = (FTSwizzler *)[en nextObject])) {
        ZYLogDebug(@"%@", swizzle);
    }
}

+ (FTSwizzleEntity *)swizzleForMethod:(Method)aMethod
{
    return (FTSwizzleEntity *)[datafluxSwizzles objectForKey:MAPTABLE_ID(aMethod)];
}

+ (void)removeSwizzleForMethod:(Method)aMethod
{
    [datafluxSwizzles removeObjectForKey:MAPTABLE_ID(aMethod)];
}

+ (void)setSwizzle:(FTSwizzleEntity *)swizzle forMethod:(Method)aMethod
{
    [datafluxSwizzles setObject:swizzle forKey:MAPTABLE_ID(aMethod)];
}

+ (BOOL)isLocallyDefinedMethod:(Method)aMethod onClass:(Class)aClass
{
    uint count;
    BOOL isLocal = NO;
    Method *methods = class_copyMethodList(aClass, &count);
    for (NSUInteger i = 0; i < count; i++) {
        if (aMethod == methods[i]) {
            isLocal = YES;
            break;
        }
    }
    free(methods);
    return isLocal;
}

+ (void)swizzleSelector:(SEL)aSelector onClass:(Class)aClass withBlock:(datafluxSwizzleBlock)aBlock named:(NSString *)aName
{
    Method aMethod = class_getInstanceMethod(aClass, aSelector);
    if (aMethod) {
        uint numArgs = method_getNumberOfArguments(aMethod);
        if (numArgs >= DATAFLUX_MIN_ARGS && numArgs <= DATAFLUX_MAX_ARGS) {
            
            BOOL isLocal = [self isLocallyDefinedMethod:aMethod onClass:aClass];
            IMP swizzledMethod = (IMP)ft_swizzledMethods[numArgs - 2];
            if (numArgs == 3) {
                char *type = method_copyArgumentType(aMethod, 2);
                NSString *firstType = [NSString stringWithCString:type encoding:NSUTF8StringEncoding];
                NSString *integerTypes = @"b";
                if ([integerTypes containsString:firstType.lowercaseString]) {
                    swizzledMethod = (IMP)ft_swizzleMethod_3_io;
                }
                free(type);
            }
            FTSwizzleEntity *swizzle = [self swizzleForMethod:aMethod];
            
            if (isLocal) {
                if (!swizzle) {
                    IMP originalMethod = method_getImplementation(aMethod);
                    
                    // Replace the local implementation of this method with the swizzled one
                    method_setImplementation(aMethod,swizzledMethod);
                    
                    // Create and add the swizzle
                    swizzle = [[FTSwizzleEntity alloc] initWithBlock:aBlock named:aName forClass:aClass selector:aSelector originalMethod:originalMethod withNumArgs:numArgs];
                    [FTSwizzler setSwizzle:swizzle forMethod:aMethod];
                    
                } else {
                    [swizzle.blocks setObject:aBlock forKey:aName];
                }
            } else {
                IMP originalMethod = swizzle ? swizzle.originalMethod : method_getImplementation(aMethod);
                
                // Add the swizzle as a new local method on the class.
                if (!class_addMethod(aClass, aSelector, swizzledMethod, method_getTypeEncoding(aMethod))) {
                    NSAssert(NO, @"SwizzlerAssert: Could not add swizzled for %@::%@, even though it didn't already exist locally", NSStringFromClass(aClass), NSStringFromSelector(aSelector));
                    return;
                }
                // Now re-get the Method, it should be the one we just added.
                Method newMethod = class_getInstanceMethod(aClass, aSelector);
                if (aMethod == newMethod) {
                    NSAssert(NO, @"SwizzlerAssert: Newly added method for %@::%@ was the same as the old method", NSStringFromClass(aClass), NSStringFromSelector(aSelector));
                    return;
                }
                
                FTSwizzleEntity *newSwizzle = [[FTSwizzleEntity alloc] initWithBlock:aBlock named:aName forClass:aClass selector:aSelector originalMethod:originalMethod withNumArgs:numArgs];
                [self setSwizzle:newSwizzle forMethod:newMethod];
            }
        } else {
            NSAssert(NO, @"SwizzlerAssert: Cannot swizzle method with %d args", numArgs);
        }
    } else {
        NSAssert(NO, @"SwizzlerAssert: Cannot find method for %@ on %@", NSStringFromSelector(aSelector), NSStringFromClass(aClass));
    }
}

+ (void)unswizzleSelector:(SEL)aSelector onClass:(Class)aClass
{
    Method aMethod = class_getInstanceMethod(aClass, aSelector);
    FTSwizzleEntity *swizzle = [self swizzleForMethod:aMethod];
    if (swizzle) {
        method_setImplementation(aMethod, swizzle.originalMethod);
        [self removeSwizzleForMethod:aMethod];
    }
}

/*
 Remove the named swizzle from the given class/selector. If aName is nil, remove all
 swizzles for this class/selector
 */
+ (void)unswizzleSelector:(SEL)aSelector onClass:(Class)aClass named:(NSString *)aName
{
    Method aMethod = class_getInstanceMethod(aClass, aSelector);
    FTSwizzleEntity *swizzle = [self swizzleForMethod:aMethod];
    if (swizzle) {
        if (aName) {
            [swizzle.blocks removeObjectForKey:aName];
        }
        if (!aName || swizzle.blocks.count == 0) {
            method_setImplementation(aMethod, swizzle.originalMethod);
            [self removeSwizzleForMethod:aMethod];
        }
    }
}
+ (void)object:(id)anObject ofClass:(Class)aClass addSelector:(SEL)aSelector
{
    NSString *objectClassSelectorString = [NSString stringWithFormat:@"%p %@ %@", anObject, NSStringFromClass(aClass), NSStringFromSelector(aSelector)];
    @synchronized(selectorCallingSet) {
        [selectorCallingSet addObject:objectClassSelectorString];
    }
}

+ (void)object:(id)anObject ofClass:(Class)aClass removeSelector:(SEL)aSelector
{
    NSString *objectClassSelectorString = [NSString stringWithFormat:@"%p %@ %@", anObject, NSStringFromClass(aClass), NSStringFromSelector(aSelector)];
    @synchronized(selectorCallingSet) {
        [selectorCallingSet removeObject:objectClassSelectorString];
    }
}

+ (BOOL)object:(id)anObject ofClass:(Class)aClass isCallingSelector:(SEL)aSelector
{
    NSString *objectClassSelectorString = [NSString stringWithFormat:@"%p %@ %@", anObject, NSStringFromClass(aClass), NSStringFromSelector(aSelector)];
    if ([selectorCallingSet containsObject:objectClassSelectorString]) {
        return YES;
    }
    return NO;
}
+ (Class)realDelegateClassFromSelector:(SEL)selector proxy:(id)proxy {
    if (!proxy) {
        return nil;
    }
    
    id realDelegate = proxy;
    id obj = nil;
    do {
        //避免proxy本身实现了该方法或通过resolveInstanceMethod添加了方法实现
        if (class_getInstanceMethod(object_getClass(realDelegate), selector)) {
            break;
        }
        
        //如果使用了NSProxy或者快速转发,判断forwardingTargetForSelector是否实现
        //默认forwardingTargetForSelector都有实现，只是返回为nil
        obj = ((id(*)(id, SEL, SEL))objc_msgSend)(realDelegate, @selector(forwardingTargetForSelector:), selector);
        if (!obj) break;
        realDelegate = obj;
    } while (obj);
    return object_getClass(realDelegate);
}

+ (BOOL)realDelegateClass:(Class)cls respondsToSelector:(SEL)sel {
    //如果cls继承自NSProxy，使用respondsToSelector来判断会崩溃
    //因为NSProxy本身未实现respondsToSelector
    return class_respondsToSelector(cls, sel);
}
@end


@implementation FTSwizzleEntity

- (instancetype)init
{
    if ((self = [super init])) {
        self.blocks = [NSMapTable mapTableWithKeyOptions:(NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPersonality)
                                            valueOptions:(NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPointerPersonality)];
    }
    return self;
}

- (instancetype)initWithBlock:(datafluxSwizzleBlock)aBlock
                        named:(NSString *)aName
                     forClass:(Class)aClass
                     selector:(SEL)aSelector
               originalMethod:(IMP)aMethod
                  withNumArgs:(uint)numArgs
{
    if ((self = [self init])) {
        self.class = aClass;
        self.selector = aSelector;
        self.numArgs = numArgs;
        self.originalMethod = aMethod;
        [self.blocks setObject:aBlock forKey:aName];
    }
    return self;
}

//- (NSString *)description
//{
//    NSString *descriptors = @"";
//    NSString *key;
//    NSEnumerator *keys = [self.blocks keyEnumerator];
//    while ((key = [keys nextObject])) {
//        descriptors = [descriptors stringByAppendingFormat:@"\t%@ : %@\n", key, [self.blocks objectForKey:key]];
//    }
//    return [NSString stringWithFormat:@"Swizzle on %@::%@ [\n%@]", NSStringFromClass(self.class), NSStringFromSelector(self.selector), descriptors];
//}


@end
@implementation FTSDKSwizzlingOnClass

- (instancetype)initWithSwizzle:(FTSwizzleEntity *)aSwizzle
                          class:(Class)aClass
{
    if ((self = [super init])) {
        self.bindingSwizzle = aSwizzle;
        self.bindingClass = aClass;
    }
    return self;
}

@end
