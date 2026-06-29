//
//  FTIDFVProvider.m
//  FTMobileSDK
//
//  Created by hulilei on 2026/6/29.
//  Copyright © 2026 DataFlux-cn. All rights reserved.
//

#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif

#import "FTIDFVProvider.h"
#import "FTSDKCompat.h"

#if FT_HAS_UIDEVICE
#import <UIKit/UIKit.h>
#endif

static NSString *const FTIDFVProviderDefaultsKey = @"ft_idfv_cache";
static NSString *FTIDFVProviderMemoryCache = nil;
static NSString *FTIDFVProviderNormalizedIdentifier(id value);

@implementation FTIDFVProvider

+ (nullable NSString *)identifierForVendor {
#if FT_HAS_UIDEVICE
    @synchronized (self) {
        NSString *memoryIdentifier = FTIDFVProviderNormalizedIdentifier(FTIDFVProviderMemoryCache);
        if (memoryIdentifier) {
            return memoryIdentifier;
        }

        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        id defaultsValue = [defaults objectForKey:FTIDFVProviderDefaultsKey];
        NSString *defaultsIdentifier = FTIDFVProviderNormalizedIdentifier(defaultsValue);
        if (defaultsIdentifier) {
            FTIDFVProviderMemoryCache = defaultsIdentifier;
            return defaultsIdentifier;
        }
        if (defaultsValue) {
            [defaults removeObjectForKey:FTIDFVProviderDefaultsKey];
        }

        NSString *systemIdentifier = FTIDFVProviderNormalizedIdentifier([self systemIdentifierForVendor]);
        if (!systemIdentifier) {
            return nil;
        }
        FTIDFVProviderMemoryCache = systemIdentifier;
        [defaults setObject:systemIdentifier forKey:FTIDFVProviderDefaultsKey];
        return systemIdentifier;
    }
#else
    return nil;
#endif
}

+ (nullable NSString *)systemIdentifierForVendor {
#if FT_HAS_UIDEVICE
    UIDevice *device = [UIDevice currentDevice];
    if (![device respondsToSelector:@selector(identifierForVendor)]) {
        return nil;
    }
    return device.identifierForVendor.UUIDString;
#else
    return nil;
#endif
}

+ (void)clearMemoryIdentifierCache {
    @synchronized (self) {
        FTIDFVProviderMemoryCache = nil;
    }
}

static NSString *FTIDFVProviderNormalizedIdentifier(id value) {
    if (![value isKindOfClass:NSString.class]) {
        return nil;
    }
    NSString *identifier = (NSString *)value;
    if (identifier.length == 0) {
        return nil;
    }
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:identifier];
    return uuid.UUIDString;
}

@end
