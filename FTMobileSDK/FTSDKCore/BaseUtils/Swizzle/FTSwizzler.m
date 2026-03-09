//
//  FTSwizzler.m
//  FTMobileAgent
//
//  Created by hulilei on 2021/7/2.
//  Copyright © 2021 hll. All rights reserved.
//
#import "FTSwizzler.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <os/lock.h>
#import "FTLog+Private.h"
#import <mach-o/dyld.h>
#import <dlfcn.h>
#if !__has_feature(objc_arc)
#error This code needs ARC. Use compiler option -fobjc-arc
#endif

#pragma mark - Swizzling

#pragma mark └ FTSwizzlerInfo
typedef IMP (^FTSwizzlerImpProvider)(void);

@interface FTSwizzlerInfo()
@property (nonatomic,copy) FTSwizzlerImpProvider impProviderBlock;
@property (nonatomic, readwrite) SEL selector;
@end

@implementation FTSwizzlerInfo

-(FTSwizzlerOriginalIMP)getOriginalImplementation{
    NSAssert(_impProviderBlock,nil);
    if (!_impProviderBlock) {
        NSLog(@"_impProviderBlock can't be missing");
        return NULL;
    }
    // Casting IMP to FTSwizzlerOriginalIMP to force user casting.
    return (FTSwizzlerOriginalIMP)_impProviderBlock();
}

@end


#pragma mark └ FTSwizzler
@implementation FTSwizzler

static void swizzle(Class classToSwizzle,
                    SEL selector,
                    FTSwizzlerImpFactoryBlock factoryBlock)
{
    Method method = class_getInstanceMethod(classToSwizzle, selector);
    
    NSCAssert(NULL != method,
              @"Selector %@ not found in %@ methods of class %@.",
              NSStringFromSelector(selector),
              class_isMetaClass(classToSwizzle) ? @"class" : @"instance",
              classToSwizzle);
    
    __block os_unfair_lock lock = OS_UNFAIR_LOCK_INIT;
    // To keep things thread-safe, we fill in the originalIMP later,
    // with the result of the class_replaceMethod call below.
    __block IMP originalIMP = NULL;
    
    // This block will be called by the client to get original implementation and call it.
    FTSwizzlerImpProvider originalImpProvider = ^IMP{
        // It's possible that another thread can call the method between the call to
        // class_replaceMethod and its return value being set.
        // So to be sure originalIMP has the right value, we need a lock.
        os_unfair_lock_lock(&lock);
        IMP imp = originalIMP;
        os_unfair_lock_unlock(&lock);
        
        if (NULL == imp){
            // If the class does not implement the method
            // we need to find an implementation in one of the superclasses.
            Class superclass = class_getSuperclass(classToSwizzle);
            imp = method_getImplementation(class_getInstanceMethod(superclass,selector));
        }
        return imp;
    };
    
    FTSwizzlerInfo *swizzleInfo = [FTSwizzlerInfo new];
    swizzleInfo.selector = selector;
    swizzleInfo.impProviderBlock = originalImpProvider;
    
    // We ask the client for the new implementation block.
    // We pass swizzleInfo as an argument to factory block, so the client can
    // call original implementation from the new implementation.
    id newIMPBlock = factoryBlock(swizzleInfo);
    
    const char *methodType = method_getTypeEncoding(method);

    IMP newIMP = imp_implementationWithBlock(newIMPBlock);
    
    // Atomically replace the original method with our new implementation.
    // This will ensure that if someone else's code on another thread is messing
    // with the class' method list too, we always have a valid method at all times.
    //
    // If the class does not implement the method itself then
    // class_replaceMethod returns NULL and superclasses's implementation will be used.
    //
    // We need a lock to be sure that originalIMP has the right value in the
    // originalImpProvider block above.
    os_unfair_lock_lock(&lock);
    originalIMP = class_replaceMethod(classToSwizzle, selector, newIMP, methodType);
    os_unfair_lock_unlock(&lock);
#if DEBUG
    Dl_info info;
        dladdr(originalIMP, &info);
    FTInnerLogInfo(@"[SWIZZLE] --------------------\nClass:%@ \nSelector:%@ \nnewIMP:%p \noriginalIMP:%p (%s)(%@)\n--------------------",classToSwizzle,NSStringFromSelector(selector),newIMP,originalIMP,info.dli_sname,[NSString stringWithUTF8String:info.dli_fname ? strrchr(info.dli_fname, '/') + 1 : ""]);
#endif
}
+ (void)setFTAssociatedObject:(id)object
                          key:(const void *)key
                        value:(nullable id)value
                  association:(objc_AssociationPolicy)association {
    objc_setAssociatedObject(object, key, value, association);
}
+ (nullable id)getFTAssociatedObject:(id)object key:(const void *)key {
    return objc_getAssociatedObject(object, key);
}
+(BOOL)swizzleInstanceMethod:(SEL)selector
                     inClass:(Class)classToSwizzle
               newImpFactory:(FTSwizzlerImpFactoryBlock)factoryBlock
                        mode:(FTSwizzlerMode)mode
                         key:(const void *)key
{
    NSAssert(!(NULL == key && FTSwizzlerModeAlways != mode),
             @"Key may not be NULL if mode is not FTSwizzlerModeAlways.");
    if (NULL == key && FTSwizzlerModeAlways != mode){
        FTInnerLogWarning(@"Key may not be NULL if mode is not FTSwizzlerModeAlways.");
        return NO;
    }
    @synchronized (self) {
        if (key){
            if (mode == FTSwizzlerModeOncePerClass) {
                if ([self getFTAssociatedObject:classToSwizzle key:key]){
                    return NO;
                }
            }else if (mode == FTSwizzlerModeOncePerClassAndSuperclasses){
                for (Class currentClass = classToSwizzle;
                     nil != currentClass;
                     currentClass = class_getSuperclass(currentClass))
                {
                    if ([self getFTAssociatedObject:currentClass key:key]) {
                        return NO;
                    }
                }
            }
        }
        swizzle(classToSwizzle, selector, factoryBlock);
        if (key){
            [self setFTAssociatedObject:classToSwizzle key:key value:@(YES) association:OBJC_ASSOCIATION_ASSIGN];
        }
    }
    return YES;
}

+(void)swizzleClassMethod:(SEL)selector
                  inClass:(Class)classToSwizzle
            newImpFactory:(FTSwizzlerImpFactoryBlock)factoryBlock
{
    [self swizzleInstanceMethod:selector
                        inClass:object_getClass(classToSwizzle)
                  newImpFactory:factoryBlock
                           mode:FTSwizzlerModeAlways
                            key:NULL];
}
+ (Class)realDelegateClassFromSelector:(SEL)selector proxy:(id)proxy {
    if (!proxy) {
        return nil;
    }
    
    id realDelegate = proxy;
    id obj = nil;
    do {
        //Avoid proxy itself implementing the method or adding method implementation through resolveInstanceMethod
        if (class_getInstanceMethod(object_getClass(realDelegate), selector)) {
            break;
        }
        
        //If NSProxy is used or fast forwarding, check if forwardingTargetForSelector is implemented
        //By default, forwardingTargetForSelector has implementation, just returns nil
        obj = ((id(*)(id, SEL, SEL))objc_msgSend)(realDelegate, @selector(forwardingTargetForSelector:), selector);
        if (!obj) break;
        realDelegate = obj;
    } while (obj);
    return object_getClass(realDelegate);
}

+ (BOOL)realDelegateClass:(Class)cls respondsToSelector:(SEL)sel {
    //If cls inherits from NSProxy, using respondsToSelector to judge will crash
    //Because NSProxy itself does not implement respondsToSelector
    return class_respondsToSelector(cls, sel);
}

@end
