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
#import <os/lock.h>
typedef NS_OPTIONS(int, FTBlockFlags) {
    FTBlockFlags_HAS_COPY_DISPOSE = (1 << 25),
    FTBlockFlags_HAS_SIGNATURE          = (1 << 30)
};
struct FT_Block_literal {
    __unused Class isa;
    FTBlockFlags flags;
    __unused int reserved;
    void (__unused *invoke)(void *, ...);
    struct {
        unsigned long int reserved;
        unsigned long int size;
        void (*copy)(void *dst, const void *src);
        void (*dispose)(const void *);
        const char *signature;
        const char *layout;
    } *descriptor;
    // imported variables
};
static const char *blockGetType(id block){
    struct FT_Block_literal *blockRef = (__bridge struct FT_Block_literal *)block;
    
    if (blockRef->flags & FTBlockFlags_HAS_SIGNATURE) {
        void *signatureLocation = blockRef->descriptor;
        signatureLocation += sizeof(unsigned long int);
        signatureLocation += sizeof(unsigned long int);
        
        if (blockRef->flags & FTBlockFlags_HAS_COPY_DISPOSE) {
            signatureLocation += sizeof(void(*)(void *dst, void *src));
            signatureLocation += sizeof(void (*)(void *src));
        }
        
        const char *signature = (*(const char **)signatureLocation);
        return signature;
    }
    
    return NULL;
}

static BOOL blockIsCompatibleWithMethodType(id block, const char *methodType){
    
    const char *blockType = blockGetType(block);
    
    NSMethodSignature *blockSignature;
    
    if (0 == strncmp(blockType, (const char *)"@\"", 2)) {
        // Block return type includes class name for id types
        // while methodType does not include.
        // Stripping out return class name.
        char *quotePtr = strchr(blockType+2, '"');
        if (NULL != quotePtr) {
            ++quotePtr;
            char filteredType[strlen(quotePtr) + 2];
            memset(filteredType, 0, sizeof(filteredType));
            *filteredType = '@';
            strncpy(filteredType + 1, quotePtr, sizeof(filteredType) - 2);
            
            blockSignature = [NSMethodSignature signatureWithObjCTypes:filteredType];
        }else{
            return NO;
        }
    }else{
        blockSignature = [NSMethodSignature signatureWithObjCTypes:blockType];
    }
    
    NSMethodSignature *methodSignature =
        [NSMethodSignature signatureWithObjCTypes:methodType];
    
    if (!blockSignature || !methodSignature) {
        return NO;
    }
    
    if (blockSignature.numberOfArguments != methodSignature.numberOfArguments){
        return NO;
    }
    
    if (strcmp(blockSignature.methodReturnType, methodSignature.methodReturnType) != 0) {
        return NO;
    }
    
    for (int i=0; i<methodSignature.numberOfArguments; ++i){
        if (i == 0){
            // self in method, block in block
            if (strcmp([methodSignature getArgumentTypeAtIndex:i], "@") != 0) {
                return NO;
            }
            if (strcmp([blockSignature getArgumentTypeAtIndex:i], "@?") != 0) {
                return NO;
            }
        }else if(i == 1){
            // SEL in method, self in block
            if (strcmp([methodSignature getArgumentTypeAtIndex:i], ":") != 0) {
                return NO;
            }
            if (strncmp([blockSignature getArgumentTypeAtIndex:i], "@", 1) != 0) {
                return NO;
            }
        }else {
            const char *blockSignatureArg = [blockSignature getArgumentTypeAtIndex:i];
            
            if (strncmp(blockSignatureArg, "@?", 2) == 0) {
                // Handle function pointer / block arguments
                blockSignatureArg = "@?";
            }
            else if (strncmp(blockSignatureArg, "@", 1) == 0) {
                blockSignatureArg = "@";
            }
            
            if (strcmp(blockSignatureArg,
                       [methodSignature getArgumentTypeAtIndex:i]) != 0)
            {
                return NO;
            }
        }
    }
    
    return YES;
}
static BOOL blockIsAnImpFactoryBlock(id block){
    const char *blockType = blockGetType(block);
    FTSwizzleImpFactoryBlock dummyFactory = ^id(FTSwizzleInfo *swizzleInfo){
        return nil;
    };
    const char *factoryType = blockGetType(dummyFactory);
    return 0 == strcmp(factoryType, blockType);
}
static void ft_performLocked(dispatch_block_t block) {
    static os_unfair_lock aspect_lock = OS_UNFAIR_LOCK_INIT;
    os_unfair_lock_lock(&aspect_lock);
    block();
    os_unfair_lock_unlock(&aspect_lock);
}
typedef IMP (^FTSWizzleImpProvider)(void);
@interface FTSwizzleInfo()
@property (nonatomic,copy) FTSWizzleImpProvider impProviderBlock;
@property (nonatomic, readwrite) SEL selector;
@end

@implementation FTSwizzleInfo

-(FTSwizzleOriginalIMP)getOriginalImplementation{
    NSAssert(_impProviderBlock,nil);
    // Casting IMP to RSSwizzleOriginalIMP to force user casting.
    return (FTSwizzleOriginalIMP)_impProviderBlock();
}

@end
@implementation FTSwizzler
static void swizzle(Class classToSwizzle,
                    SEL selector,
                    FTSwizzleImpFactoryBlock factoryBlock)
{
    Method method = class_getInstanceMethod(classToSwizzle, selector);
    
    NSCAssert(NULL != method,
              @"Selector %@ not found in %@ methods of class %@.",
              NSStringFromSelector(selector),
              class_isMetaClass(classToSwizzle) ? @"class" : @"instance",
              classToSwizzle);
    
    NSCAssert(blockIsAnImpFactoryBlock(factoryBlock),
             @"Wrong type of implementation factory block.");
    
    
    __block IMP originalIMP = NULL;
    //如果当前类中有该方法，则返回原有的imp
    //如果当前类中没有该方法，去父类查找返回父类该方法的imp 并没有将父类的方法添加到子类的操作，避免了父类方法被动态修改导致的hook异常
    FTSWizzleImpProvider originalImpProvider = ^IMP{
        
        __block IMP imp;
        ft_performLocked(^{
            imp = originalIMP;
        });
        
        if (NULL == imp){
            //如果当前类并没有实现此方法，则去父类里找到该方法
            Class superclass = class_getSuperclass(classToSwizzle);
            imp = method_getImplementation(class_getInstanceMethod(superclass,selector));
        }
        return imp;
    };
    
    FTSwizzleInfo *swizzleInfo = [FTSwizzleInfo new];
    swizzleInfo.selector = selector;
    swizzleInfo.impProviderBlock = originalImpProvider;
    
    
    id newIMPBlock = factoryBlock(swizzleInfo);
    
    const char *methodType = method_getTypeEncoding(method);
    
    NSCAssert(blockIsCompatibleWithMethodType(newIMPBlock,methodType),
             @"Block returned from factory is not compatible with method type.");
    
    IMP newIMP = imp_implementationWithBlock(newIMPBlock);
    

    ft_performLocked(^{
        originalIMP = class_replaceMethod(classToSwizzle, selector, newIMP, methodType);
    });

}
+(void)swizzleInstanceMethod:(SEL)selector
                     inClass:(Class)classToSwizzle
               newImpFactory:(FTSwizzleImpFactoryBlock)factoryBlock
{
    
    swizzle(classToSwizzle, selector, factoryBlock);
    
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
