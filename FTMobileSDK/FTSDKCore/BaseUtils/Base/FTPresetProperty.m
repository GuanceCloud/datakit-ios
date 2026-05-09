//
//  FTPresetProperty.m
//  FTMobileAgent
//
//  Created by hulilei on 2020/10/23.
//  Copyright © 2020 hll. All rights reserved.
//
#import "FTBaseInfoHandler.h"
#import "FTSDKCompat.h"
#if FT_HAS_UIKIT
#import <UIKit/UIKit.h>
#endif
#import "FTPresetProperty.h"
#import <sys/utsname.h>
#import "FTJSONUtil.h"
#import "FTUserInfo.h"
#import "FTConstants.h"
#include <mach-o/dyld.h>
#include <mach-o/nlist.h>
#import "FTInnerLog.h"
#import "FTNetworkConnectivity.h"
#import "NSDictionary+FTCopyProperties.h"
#include <mach-o/arch.h>
#include <sys/sysctl.h>
#import "FTThreadDispatchManager.h"
#if FT_HOST_MAC
#import <AppKit/AppKit.h>
#import <IOKit/IOKitLib.h>
#endif
#import <pthread.h>
static BOOL FTPresetIsAppExtension(void) {
    return [[[NSBundle mainBundle] bundleURL].pathExtension isEqualToString:@"appex"];
}

@interface MobileDevice : NSObject
@property (nonatomic,copy,readonly) NSString *os;
@property (nonatomic,copy,readonly) NSString *device;
@property (nonatomic,copy,readonly) NSString *model;
@property (nonatomic,copy,readonly) NSString *deviceUUID;
@property (nonatomic,copy,readonly) NSString *osVersion;
@property (nonatomic,copy,readonly) NSString *osVersionMajor;
@property (nonatomic,copy,readonly) NSString *screenSize;
@property (nonatomic,copy,readonly) NSString *cpuArch;
@property (nonatomic,copy,readonly) NSString *appUUID;
@end
@implementation MobileDevice
-(instancetype)init{
    self = [super init];
    if (self) {
        _device = @"APPLE";
#if FT_HAS_UIKIT
        _model = [FTPresetProperty deviceInfo];
        _deviceUUID = [[UIDevice currentDevice] identifierForVendor].UUIDString;
        _os = [UIDevice currentDevice].systemName;
        if (!FTPresetIsAppExtension()) {
            _appUUID = [FTPresetProperty getApplicationUUID];
        }
#elif FT_HOST_MAC
        _os = @"macOS";
        NSRect rect = [NSScreen mainScreen].frame;
        _screenSize = [[NSString alloc] initWithFormat:@"%.f*%.f",rect.size.height,rect.size.width];
        _deviceUUID = [FTPresetProperty getDeviceUUID];
        _model = [FTPresetProperty macOSDeviceModel];
#endif
        _cpuArch = [FTPresetProperty cpuArch];
        _osVersion = [FTPresetProperty getOSVersion];
        NSArray *versionComponents = [_osVersion componentsSeparatedByString:@"."];
        if (versionComponents.count > 0) {
            _osVersionMajor = versionComponents.firstObject;
        } else {
            _osVersionMajor = _osVersion;
        }
    }
    return self;
}
#if FT_HAS_UIKIT
- (NSArray<UIWindow *> *)windows{
    __block NSArray<UIWindow *> *windows = nil;
    [FTThreadDispatchManager performBlockDispatchMainSyncSafe:^{
        UIApplication *app = [self sharedApplication];
        NSMutableSet *result = [NSMutableSet set];
        
        if (@available(iOS 13.0, tvOS 13.0, *)) {
            NSArray<UIScene *> *scenes = [self getApplicationConnectedScenes:app];
            for (UIScene *scene in scenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive
                    && scene.delegate &&
                    [scene.delegate respondsToSelector:@selector(window)]) {
                    id window = [scene.delegate performSelector:@selector(window)];
                    if (window) {
                        [result addObject:window];
                    }
                }
            }
        }
        id<UIApplicationDelegate> appDelegate = [self getApplicationDelegate:app];
        if ([appDelegate respondsToSelector:@selector(window)] && appDelegate.window != nil) {
            [result addObject:appDelegate.window];
        }
        windows = [result allObjects];
    }
                                                      timeout:0.1];
    return windows ?: @[];
}
- (NSArray<UIScene *> *)getApplicationConnectedScenes:(UIApplication *)application API_AVAILABLE(ios(13.0), tvos(13.0)){
    if (application && [application respondsToSelector:@selector(connectedScenes)]) {
        return [application.connectedScenes allObjects];
    }
    return @[];
}
- (nullable id<UIApplicationDelegate>)getApplicationDelegate:(UIApplication *)application{
    return application.delegate;
}
- (UIApplication *)sharedApplication{
    if (![UIApplication respondsToSelector:@selector(sharedApplication)])
        return nil;
    return [UIApplication performSelector:@selector(sharedApplication)];
}
- (NSString *)screenSize{
    NSArray<UIWindow *> *appWindows = self.windows;
    if ([appWindows count] > 0) {
        __block UIScreen *appScreen;
        [FTThreadDispatchManager performBlockDispatchMainSyncSafe:^{
            appScreen = appWindows.firstObject.screen;
        } timeout:0.1];
        if (appScreen != nil) {
            return [[NSString alloc] initWithFormat:@"%.f*%.f",appScreen.nativeBounds.size.width,appScreen.nativeBounds.size.height];
        }
    }
    return nil;
}
#endif
@end

static NSString *FTPresetStringKey(id key) {
    if ([key isKindOfClass:NSString.class]) {
        return key;
    }
    if ([key respondsToSelector:@selector(description)]) {
        return [key description];
    }
    return nil;
}

static id FTPresetApplyModifier(FTDataModifier modifier, NSString *key, id value, Class expectedClass) {
    if (!value || key.length == 0) {
        return nil;
    }
    if (!modifier) {
        return value;
    }
    id modifiedValue = modifier(key, value);
    if (!modifiedValue) {
        return value;
    }
    if (expectedClass && ![modifiedValue isKindOfClass:expectedClass]) {
        FTInnerLogWarning(@"dataModifier returned invalid value type for key: %@, value: %@, type: %@", key, modifiedValue, [modifiedValue class]);
        return value;
    }
    return modifiedValue;
}

static NSDictionary *FTPresetApplyModifierToDictionary(NSDictionary *dictionary, FTDataModifier modifier) {
    NSDictionary *normalizedDictionary = [NSObject ft_normalizedDictionaryWithObject:dictionary];
    if (!modifier || normalizedDictionary.count == 0) {
        return normalizedDictionary;
    }
    NSMutableDictionary *result = [NSMutableDictionary dictionaryWithCapacity:normalizedDictionary.count];
    [normalizedDictionary enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        NSString *stringKey = FTPresetStringKey(key);
        if (stringKey.length == 0 || !obj) {
            return;
        }
        id value = FTPresetApplyModifier(modifier, stringKey, obj, nil);
        if (value) {
            result[stringKey] = value;
        }
    }];
    return [result copy];
}

static Class FTPresetExpectedValueClass(id value) {
    if ([value isKindOfClass:NSString.class]) return NSString.class;
    if ([value isKindOfClass:NSNumber.class]) return NSNumber.class;
    if ([value isKindOfClass:NSDictionary.class]) return NSDictionary.class;
    if ([value isKindOfClass:NSArray.class]) return NSArray.class;
    if ([value isKindOfClass:NSSet.class]) return NSSet.class;
    return Nil;
}

@interface FTPresetPropertyModel : NSObject
+ (NSDictionary<NSString *, NSString *> *)ft_codingKeys;
+ (NSSet<NSString *> *)ft_flattenPropertyNames;
+ (NSSet<NSString *> *)ft_ignoredPropertyNames;
- (void)ft_applyModifier:(FTDataModifier)modifier;
- (NSDictionary *)ft_tags;
@end

@implementation FTPresetPropertyModel
+ (NSDictionary<NSString *, NSString *> *)ft_codingKeys {
    static NSDictionary *keys = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        keys = @{};
    });
    return keys;
}
+ (NSSet<NSString *> *)ft_flattenPropertyNames {
    static NSSet *names = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        names = [NSSet set];
    });
    return names;
}
+ (NSSet<NSString *> *)ft_ignoredPropertyNames {
    static NSSet *names = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        names = [NSSet set];
    });
    return names;
}
- (id)ft_modifiedValue:(id)value key:(NSString *)key expectedClass:(Class)expectedClass modifier:(FTDataModifier)modifier {
    if (!value || value == (id)kCFNull || [value isKindOfClass:NSNull.class] || key.length == 0) {
        return nil;
    }
    if (!modifier) {
        return value;
    }
    id modifiedValue = modifier(key, value);
    if (!modifiedValue) {
        return value;
    }
    if (expectedClass && ![modifiedValue isKindOfClass:expectedClass]) {
        FTInnerLogWarning(@"dataModifier returned invalid value type for key: %@, value: %@, type: %@", key, modifiedValue, [modifiedValue class]);
        return value;
    }
    return modifiedValue;
}
- (void)ft_applyModifier:(FTDataModifier)modifier {
    if (!modifier) {
        return;
    }
    for (NSString *propertyName in [[self class] ft_flattenPropertyNames]) {
        @try {
            id value = [self valueForKey:propertyName];
            [self setValue:FTPresetApplyModifierToDictionary(value, modifier) forKey:propertyName];
        } @catch (NSException *exception) {
            FTInnerLogWarning(@"preset property modifier failed: %@, %@", propertyName, exception);
            continue;
        }
    }
    [[[self class] ft_codingKeys] enumerateKeysAndObjectsUsingBlock:^(NSString *propertyName, NSString *key, BOOL *stop) {
        @try {
            id value = [self valueForKey:propertyName];
            id modifiedValue = [self ft_modifiedValue:value key:key expectedClass:FTPresetExpectedValueClass(value) modifier:modifier];
            [self setValue:modifiedValue forKey:propertyName];
        } @catch (NSException *exception) {
            FTInnerLogWarning(@"preset property modifier failed: %@, %@", propertyName, exception);
        }
    }];
}
- (NSDictionary *)ft_tags {
    NSMutableDictionary *tags = [NSMutableDictionary dictionary];
    for (NSString *propertyName in [[self class] ft_flattenPropertyNames]) {
        @try {
            [tags addEntriesFromDictionary:[NSObject ft_normalizedDictionaryWithObject:[self valueForKey:propertyName]]];
        } @catch (NSException *exception) {
            FTInnerLogWarning(@"preset property read failed: %@, %@", propertyName, exception);
            continue;
        }
    }
    [[[self class] ft_codingKeys] enumerateKeysAndObjectsUsingBlock:^(NSString *propertyName, NSString *key, BOOL *stop) {
        @try {
            id value = [self valueForKey:propertyName];
            if (key.length > 0 && value && value != (id)kCFNull && ![value isKindOfClass:NSNull.class]) {
                tags[key] = value;
            }
        } @catch (NSException *exception) {
            FTInnerLogWarning(@"preset property read failed: %@, %@", propertyName, exception);
        }
    }];
    return [tags copy];
}
@end

@interface FTBasePropertyModel : FTPresetPropertyModel
@property (nonatomic, copy) NSString *applicationUUID;
@property (nonatomic, copy) NSString *deviceUUID;
@property (nonatomic, copy) NSString *service;
@property (nonatomic, copy) NSString *version;
@property (nonatomic, copy) NSString *env;
@property (nonatomic, strong) NSDictionary *sdkPkgInfo;
@property (nonatomic, copy) NSString *sdkVersion;
@property (nonatomic, copy) NSString *sdkName;
@property (nonatomic, copy) NSString *networkType;

@property (nonatomic, strong) NSDictionary *globalContext;
@property (nonatomic, strong) NSDictionary *dynamicGlobalContext;
@property (nonatomic, strong) NSDictionary *userInfo;

- (void)appendGlobalContext:(NSDictionary *)context modifier:(FTDataModifier)modifier;
- (void)updateUserInfo:(NSDictionary *)userInfo modifier:(FTDataModifier)modifier;
- (void)updateNetworkType:(NSString *)networkType modifier:(FTDataModifier)modifier;
@end
@implementation FTBasePropertyModel
+ (NSDictionary<NSString *, NSString *> *)ft_codingKeys {
    static NSDictionary *keys = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        keys = @{
            @"applicationUUID": FT_APPLICATION_UUID,
            @"deviceUUID": FT_COMMON_PROPERTY_DEVICE_UUID,
            @"service": FT_KEY_SERVICE,
            @"version": FT_VERSION,
            @"env": FT_ENV,
            @"sdkPkgInfo": FT_SDK_PKG_INFO,
            @"sdkVersion": FT_SDK_VERSION,
            @"sdkName": FT_SDK_NAME,
            @"networkType": FT_NETWORK_TYPE,
        };
    });
    return keys;
}
+ (NSSet<NSString *> *)ft_flattenPropertyNames {
    static NSSet *names = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        names = [NSSet setWithArray:@[@"globalContext", @"dynamicGlobalContext", @"userInfo"]];
    });
    return names;
}
- (void)appendGlobalContext:(NSDictionary *)context modifier:(FTDataModifier)modifier {
    NSDictionary *newContext = FTPresetApplyModifierToDictionary(context, modifier);
    if (newContext.count == 0) {
        return;
    }
    NSMutableDictionary *result = [NSMutableDictionary dictionaryWithDictionary:self.dynamicGlobalContext ?: @{}];
    [result addEntriesFromDictionary:newContext];
    self.dynamicGlobalContext = [result copy];
}
- (void)updateUserInfo:(NSDictionary *)userInfo modifier:(FTDataModifier)modifier {
    self.userInfo = FTPresetApplyModifierToDictionary(userInfo, modifier);
}
- (void)updateNetworkType:(NSString *)networkType modifier:(FTDataModifier)modifier {
    self.networkType = [self ft_modifiedValue:networkType key:FT_NETWORK_TYPE expectedClass:NSString.class modifier:modifier];
}
@end

@interface FTRUMPropertyModel : FTPresetPropertyModel
@property (nonatomic, strong) FTBasePropertyModel *baseModel;
@property (nonatomic, copy) NSString *device;
@property (nonatomic, copy) NSString *deviceModel;
@property (nonatomic, copy) NSString *os;
@property (nonatomic, copy) NSString *osVersion;
@property (nonatomic, copy) NSString *osVersionMajor;
@property (nonatomic, copy) NSString *cpuArch;
@property (nonatomic, copy) NSString *appId;
@property (nonatomic, strong) NSDictionary *rumGlobalContext;
@property (nonatomic, strong) NSDictionary *dynamicRUMGlobalContext;
@property (nonatomic, copy) NSString *customKeys;
@property (nonatomic, copy) NSString *screenSize;
- (void)appendRUMGlobalContext:(NSDictionary *)context modifier:(FTDataModifier)modifier;
- (void)updateCustomKeys;
- (void)updateScreenSize:(NSString *)screenSize modifier:(FTDataModifier)modifier;
- (NSDictionary *)tags;
@end
@implementation FTRUMPropertyModel
+ (NSDictionary<NSString *, NSString *> *)ft_codingKeys {
    static NSDictionary *keys = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        keys = @{
            @"device": FT_COMMON_PROPERTY_DEVICE,
            @"deviceModel": FT_COMMON_PROPERTY_DEVICE_MODEL,
            @"os": FT_COMMON_PROPERTY_OS,
            @"osVersion": FT_COMMON_PROPERTY_OS_VERSION,
            @"osVersionMajor": FT_COMMON_PROPERTY_OS_VERSION_MAJOR,
            @"cpuArch": FT_CPU_ARCH,
            @"appId": FT_APP_ID,
            @"customKeys": FT_RUM_CUSTOM_KEYS,
            @"screenSize": FT_SCREEN_SIZE,
        };
    });
    return keys;
}
+ (NSSet<NSString *> *)ft_flattenPropertyNames {
    static NSSet *names = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        names = [NSSet setWithArray:@[@"rumGlobalContext", @"dynamicRUMGlobalContext"]];
    });
    return names;
}
+ (NSSet<NSString *> *)ft_ignoredPropertyNames {
    static NSSet *names = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        names = [NSSet setWithObject:@"baseModel"];
    });
    return names;
}
- (void)appendRUMGlobalContext:(NSDictionary *)context modifier:(FTDataModifier)modifier {
    NSDictionary *newContext = FTPresetApplyModifierToDictionary(context, modifier);
    if (newContext.count == 0) {
        return;
    }
    NSMutableDictionary *result = [NSMutableDictionary dictionaryWithDictionary:self.dynamicRUMGlobalContext ?: @{}];
    [result addEntriesFromDictionary:newContext];
    self.dynamicRUMGlobalContext = [result copy];
    [self updateCustomKeys];
}
- (void)updateCustomKeys {
    NSMutableArray *allKeys = [NSMutableArray array];
    NSDictionary *dynamicContext = [NSObject ft_normalizedDictionaryWithObject:self.dynamicRUMGlobalContext];
    if (dynamicContext.count > 0) {
        [allKeys addObjectsFromArray:dynamicContext.allKeys];
    }
    NSDictionary *staticContext = [NSObject ft_normalizedDictionaryWithObject:self.rumGlobalContext];
    if (staticContext.count > 0) {
        [allKeys addObjectsFromArray:staticContext.allKeys];
    }
    self.customKeys = allKeys.count > 0 ? [FTJSONUtil convertToJsonDataWithObject:allKeys] : nil;
}
- (void)updateScreenSize:(NSString *)screenSize modifier:(FTDataModifier)modifier {
    self.screenSize = [self ft_modifiedValue:screenSize key:FT_SCREEN_SIZE expectedClass:NSString.class modifier:modifier];
}
- (NSDictionary *)tags {
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:[self.baseModel ft_tags]];
    [dict addEntriesFromDictionary:[self ft_tags]];
    return [dict copy];
}
@end

@interface FTLogPropertyModel : FTPresetPropertyModel
@property (nonatomic, strong) FTBasePropertyModel *baseModel;
@property (nonatomic, strong) NSDictionary *logGlobalContext;
@property (nonatomic, strong) NSDictionary *dynamicLogGlobalContext;
- (void)appendLogGlobalContext:(NSDictionary *)context modifier:(FTDataModifier)modifier;
- (NSDictionary *)tags;
@end
@implementation FTLogPropertyModel
+ (NSSet<NSString *> *)ft_flattenPropertyNames {
    static NSSet *names = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        names = [NSSet setWithArray:@[@"logGlobalContext", @"dynamicLogGlobalContext"]];
    });
    return names;
}
+ (NSSet<NSString *> *)ft_ignoredPropertyNames {
    static NSSet *names = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        names = [NSSet setWithObject:@"baseModel"];
    });
    return names;
}
- (void)appendLogGlobalContext:(NSDictionary *)context modifier:(FTDataModifier)modifier {
    NSDictionary *newContext = FTPresetApplyModifierToDictionary(context, modifier);
    if (newContext.count == 0) {
        return;
    }
    NSMutableDictionary *result = [NSMutableDictionary dictionaryWithDictionary:self.dynamicLogGlobalContext ?: @{}];
    [result addEntriesFromDictionary:newContext];
    self.dynamicLogGlobalContext = [result copy];
}
- (NSDictionary *)tags {
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:[self.baseModel ft_tags]];
    [dict addEntriesFromDictionary:[self ft_tags]];
    return [dict copy];
}
@end

@interface FTPresetProperty ()<FTNetworkChangeObserver>
@property (nonatomic, copy) FTDataModifier dataModifier;
@property (nonatomic, copy) FTLineDataModifier lineDataModifier;
@property (nonatomic, strong, readwrite) NSDictionary *sessionReplayTags;
@property (nonatomic, strong) FTBasePropertyModel *basePropertyModel;
@property (nonatomic, strong) FTRUMPropertyModel *rumPropertyModel;
@property (nonatomic, strong) FTLogPropertyModel *logPropertyModel;

/// device basic info
@property (nonatomic, strong) MobileDevice *mobileDevice;
@property (nonatomic, strong) FTUserInfo *userInfo;
@end
@implementation FTPresetProperty{
    pthread_rwlock_t _rwLock;
    BOOL _rumScreenSizeResolved;
}
@synthesize dataModifier = _dataModifier;
@synthesize lineDataModifier = _lineDataModifier;
@synthesize sessionReplayTags = _sessionReplayTags;

+ (instancetype)sharedInstance{
    static dispatch_once_t onceToken;
    static FTPresetProperty *sharedInstance = nil;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[FTPresetProperty alloc]init];
    });
    return sharedInstance;
}
-(instancetype)init{
    self = [super init];
    if (self){
        _mobileDevice = [[MobileDevice alloc]init];
        _userInfo = [FTUserInfo new];
        pthread_rwlock_init(&_rwLock, NULL);
    }
    return self;
}
// sdkConfig
- (void)startWithVersion:(NSString *)version
              sdkVersion:(NSString *)sdkVersion
                     env:(NSString *)env
                 service:(NSString *)service
           globalContext:(NSDictionary *)globalContext
                 pkgInfo:(NSDictionary *)pkgInfo{
    FTBasePropertyModel *baseModel = [FTBasePropertyModel new];
    baseModel.applicationUUID = self.mobileDevice.appUUID;
    baseModel.deviceUUID = self.mobileDevice.deviceUUID;
    baseModel.service = service;
    baseModel.version = version;
    baseModel.env = env;
    baseModel.sdkPkgInfo = [NSObject ft_normalizedDictionaryWithObject:pkgInfo];
    baseModel.sdkVersion = sdkVersion;
    baseModel.sdkName = FT_SDK_NAME_VALUE;
    baseModel.globalContext = [NSObject ft_normalizedDictionaryWithObject:globalContext];
    [baseModel ft_applyModifier:self.dataModifier];
    
    NSMutableDictionary *srDict = [NSMutableDictionary dictionary];
    [srDict setValue:service forKey:FT_KEY_SERVICE];
    [srDict setValue:version forKey:FT_VERSION];
    [srDict setValue:env forKey:FT_ENV];
    [srDict setValue:sdkVersion forKey:FT_SDK_VERSION];
    [srDict setValue:FT_IOS_SDK_NAME forKey:FT_SDK_NAME];
    [srDict setValue:@"ios" forKey:FT_KEY_SOURCE];
    
    [self safeWrite:^{
        self->_basePropertyModel = baseModel;
        self->_sessionReplayTags = srDict;
    }];
}
// rumTags
- (void)setRUMAppID:(NSString *)appID
         sampleRate:(int)sampleRate
 sessionOnErrorSampleRate:(int)sessionOnErrorSampleRate
   rumGlobalContext:(NSDictionary *)rumGlobalContext {
    FTRUMPropertyModel *rumModel = [FTRUMPropertyModel new];
    rumModel.baseModel = [self currentBasePropertyModel];
    rumModel.device = self.mobileDevice.device;
    rumModel.deviceModel = self.mobileDevice.model;
    rumModel.os = self.mobileDevice.os;
    rumModel.osVersion = self.mobileDevice.osVersion;
    rumModel.osVersionMajor = self.mobileDevice.osVersionMajor;
    rumModel.cpuArch = self.mobileDevice.cpuArch;
    rumModel.appId = appID;
    rumModel.rumGlobalContext = [NSObject ft_normalizedDictionaryWithObject:rumGlobalContext];
    [rumModel ft_applyModifier:self.dataModifier];
    [rumModel updateCustomKeys];
    [[FTNetworkConnectivity sharedInstance] addNetworkObserver:self];
    NSString *networkType = [FTNetworkConnectivity sharedInstance].networkType;
    FTDataModifier modifier = self.dataModifier;
    [self safeWrite:^{
        [self->_basePropertyModel updateUserInfo:[self->_userInfo userInfoDict] modifier:modifier];
        [self->_basePropertyModel updateNetworkType:networkType modifier:modifier];
        self->_rumPropertyModel = rumModel;
        self->_rumScreenSizeResolved = NO;
    }];
}
- (void)connectivityChanged:(BOOL)connected typeDescription:(NSString *)typeDescription{
    FTDataModifier modifier = self.dataModifier;
    [self safeWrite:^{
        [self->_basePropertyModel updateNetworkType:typeDescription modifier:modifier];
    }];
}
- (void)setLogGlobalContext:(NSDictionary *)logGlobalContext {
    FTLogPropertyModel *logModel = [FTLogPropertyModel new];
    logModel.baseModel = [self currentBasePropertyModel];
    logModel.logGlobalContext = [NSObject ft_normalizedDictionaryWithObject:logGlobalContext];
    [logModel ft_applyModifier:self.dataModifier];
    [self safeWrite:^{
        self->_logPropertyModel = logModel;
    }];
}
#pragma mark ----property setter/getter thread safe ----
-(FTBasePropertyModel *)currentBasePropertyModel{
    __block FTBasePropertyModel *model;
    pthread_rwlock_rdlock(&_rwLock);
    model = self->_basePropertyModel;
    pthread_rwlock_unlock(&_rwLock);
    return model;
}
-(FTLogPropertyModel *)ensureLogPropertyModel{
    __block FTLogPropertyModel *model;
    __block FTBasePropertyModel *baseModel;
    pthread_rwlock_rdlock(&_rwLock);
    model = self->_logPropertyModel;
    baseModel = self->_basePropertyModel;
    pthread_rwlock_unlock(&_rwLock);
    if (model || !baseModel) {
        return model;
    }
    model = [FTLogPropertyModel new];
    model.baseModel = baseModel;
    [self safeWrite:^{
        if (!self->_logPropertyModel) {
            self->_logPropertyModel = model;
        }
        model = self->_logPropertyModel;
    }];
    return model;
}
-(NSDictionary *)loggerTags{
    [self ensureLogPropertyModel];
    __block NSDictionary *tags;
    pthread_rwlock_rdlock(&_rwLock);
    tags = [[self->_logPropertyModel tags] copy];
    pthread_rwlock_unlock(&_rwLock);
    return tags ?: @{};
}
-(void)setDataModifier:(FTDataModifier)dataModifier{
    pthread_rwlock_wrlock(&_rwLock);
    _dataModifier = dataModifier;
    pthread_rwlock_unlock(&_rwLock);
}
-(FTDataModifier)dataModifier{
    __block FTDataModifier obj;
    pthread_rwlock_rdlock(&_rwLock);
    obj = [self->_dataModifier copy];
    pthread_rwlock_unlock(&_rwLock);
    return obj;
}
-(void)setLineDataModifier:(FTLineDataModifier)lineDataModifier{
    pthread_rwlock_wrlock(&_rwLock);
    _lineDataModifier = lineDataModifier;
    pthread_rwlock_unlock(&_rwLock);
}
-(FTLineDataModifier)lineDataModifier{
    __block FTLineDataModifier obj;
    pthread_rwlock_rdlock(&_rwLock);
    obj = [self->_lineDataModifier copy];
    pthread_rwlock_unlock(&_rwLock);
    return obj;
}
-(void)ensureRUMScreenSize{
    __block BOOL needsScreenSize = NO;
    __block FTRUMPropertyModel *rumModel;
    pthread_rwlock_rdlock(&_rwLock);
    rumModel = self->_rumPropertyModel;
    needsScreenSize = rumModel != nil && !self->_rumScreenSizeResolved && rumModel.screenSize.length == 0;
    pthread_rwlock_unlock(&_rwLock);
    if (!needsScreenSize) {
        return;
    }
    if (FTPresetIsAppExtension()) {
        [self safeWrite:^{
            self->_rumScreenSizeResolved = YES;
        }];
        return;
    }
    NSString *screen = [self.mobileDevice screenSize];
    FTDataModifier modifier = self.dataModifier;
    [self safeWrite:^{
        if (self->_rumPropertyModel.screenSize.length == 0) {
            if (screen.length > 0) {
                [self->_rumPropertyModel updateScreenSize:screen modifier:modifier];
            }
            self->_rumScreenSizeResolved = YES;
        }
    }];
}
-(NSDictionary *)rumTags{
    [self ensureRUMScreenSize];
    __block NSDictionary *tags;
    pthread_rwlock_rdlock(&_rwLock);
    tags = [[self->_rumPropertyModel tags] copy];
    pthread_rwlock_unlock(&_rwLock);
    return tags ?: @{};
}
- (void)safeWrite:(void (^)(void))block{
    if (!block) return;
    pthread_rwlock_wrlock(&_rwLock);
    @try {
        block();
    } @finally {
        pthread_rwlock_unlock(&_rwLock);
    }
}
#pragma mark ---- api ----
-(void)setDataModifier:(FTDataModifier )dataModifier lineDataModifier:(FTLineDataModifier)lineDataModifier{
    FTDataModifier copyDataModifier = [dataModifier copy];
    FTLineDataModifier copyLineDataModifier = [lineDataModifier copy];
    [self safeWrite:^{
        self->_dataModifier = copyDataModifier;
        self->_lineDataModifier = copyLineDataModifier;
    }];
}
-(void)updateUser:(NSString *)Id name:(NSString *)name email:(NSString *)email extra:(NSDictionary *)extra{
    FTDataModifier modifier = self.dataModifier;
    [self safeWrite:^{
        [self->_userInfo updateUser:Id name:name email:email extra:extra];
        NSDictionary *userInfoDict = [self->_userInfo userInfoDict];
        [self->_basePropertyModel updateUserInfo:userInfoDict modifier:modifier];
    }];
}
-(void)clearUser{
    FTDataModifier modifier = self.dataModifier;
    [self safeWrite:^{
        [self->_userInfo clearUser];
        NSDictionary *userInfoDict = [self->_userInfo userInfoDict];
        [self->_basePropertyModel updateUserInfo:userInfoDict modifier:modifier];
    }];
}
- (NSDictionary *)loggerDynamicTags{
    return [self loggerTags] ?: @{};
}
-(void)setSessionReplaySource:(NSString *)sessionReplaySource{
    NSMutableDictionary *srDict = [self.sessionReplayTags mutableCopy] ?: [NSMutableDictionary dictionary];
    [srDict setValue:sessionReplaySource forKey:FT_KEY_SOURCE];
    self.sessionReplayTags = srDict;
}
- (NSDictionary *)rumDynamicTags{
    return [self rumTags] ?: @{};
}
- (void)appendGlobalContext:(NSDictionary *)context{
    FTDataModifier modifier = self.dataModifier;
    [self safeWrite:^{
        [self->_basePropertyModel appendGlobalContext:context modifier:modifier];
    }];
}
- (void)appendRUMGlobalContext:(NSDictionary *)context{
    FTDataModifier modifier = self.dataModifier;
    [self safeWrite:^{
        [self->_rumPropertyModel appendRUMGlobalContext:context modifier:modifier];
    }];
}
- (void)appendLogGlobalContext:(NSDictionary *)context{
    [self ensureLogPropertyModel];
    FTDataModifier modifier = self.dataModifier;
    [self safeWrite:^{
        [self->_logPropertyModel appendLogGlobalContext:context modifier:modifier];
    }];
}
- (NSDictionary *)applyModifier:(NSDictionary *)dict{
    NSDictionary *normalizedDict = [NSObject ft_normalizedDictionaryWithObject:dict];
    FTDataModifier tempModifier = self.dataModifier;
    if (tempModifier == nil || normalizedDict.count == 0) return normalizedDict;
    return FTPresetApplyModifierToDictionary(normalizedDict, tempModifier);
}
- (NSArray<NSDictionary *> *)applyLineModifier:(NSString *)measurement
                                         tags:(NSDictionary *)tags
                                       fields:(NSDictionary *)fields {
    // Quick termination condition: when lineDataModifier is nil, return original data directly (defensive handling)
    FTLineDataModifier tempLineModifier = self.lineDataModifier;
    if (!tempLineModifier) {
        return nil;
    }

    FTLinePropertyBag *lineBag = [[FTLinePropertyBag alloc] initWithTags:tags fields:fields];
    // Execute Block and validate return value
    FTLinePropertyBag *changedBag = [lineBag bagByApplyingChangedValues:tempLineModifier(measurement, lineBag.mergedDictionary)];
    return @[ changedBag.tags, changedBag.fields ];
}
+ (NSString *)getApplicationUUID{
    // Get image index
    const uint32_t imageCount = _dyld_image_count();
    uint32_t mainImg = 0;
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSDictionary *infoDict = [mainBundle infoDictionary];
    NSString *bundlePath = [mainBundle bundlePath];
    NSString *executableName = infoDict[@"CFBundleExecutable"];
    for(uint32_t iImg = 0; iImg < imageCount; iImg++) {
        const char* name = _dyld_get_image_name(iImg);
        NSString *imagePath = [NSString stringWithUTF8String:name];
        if ([imagePath containsString:bundlePath]&&[[imagePath lastPathComponent] isEqualToString:executableName]){
            mainImg = iImg;
            // Get header based on index
            const struct mach_header* header = _dyld_get_image_header(mainImg);
            uintptr_t cmdPtr = firstCmdAfterHeader(header);
            if(cmdPtr == 0) {
                return @"NULL";
            }
            uint8_t* uuid = NULL;
            for(uint32_t iCmd = 0; iCmd < header->ncmds; iCmd++){
                struct load_command* loadCmd = (struct load_command*)cmdPtr;
                if (loadCmd->cmd == LC_UUID) {
                    struct uuid_command* uuidCmd = (struct uuid_command*)cmdPtr;
                    uuid = uuidCmd->uuid;
                    break;
                }
                cmdPtr += loadCmd->cmdsize;
            }
            if(uuid != NULL){
                CFUUIDRef uuidRef = CFUUIDCreateFromUUIDBytes(NULL, *((CFUUIDBytes*)uuid));
                NSString* str = (__bridge_transfer NSString*)CFUUIDCreateString(NULL, uuidRef);
                CFRelease(uuidRef);
                return str == NULL ? @"NULL" : str;
            }
        }
    }
    return @"NULL";
}
//// Get Load Command
static uintptr_t firstCmdAfterHeader(const struct mach_header* const header) {
    switch(header->magic)
    {
        case MH_MAGIC:
        case MH_CIGAM:
            return (uintptr_t)(header + 1);
        case MH_MAGIC_64:
        case MH_CIGAM_64:
            return (uintptr_t)(((struct mach_header_64*)header) + 1);
        default:
            // Header is corrupt
            return 0;
    }
}
+ (NSString *)cpuArch{
    int32_t cpuType = 0;
    size_t size = sizeof(cpuType);
    
    int res = sysctlbyname("hw.cputype", &cpuType, &size, NULL, 0);
    if(res != 0){
        cpuType = 0;
    }
    int32_t cpuSubType = 0;
    size_t subSize = sizeof(cpuSubType);
    res = sysctlbyname("hw.cpusubtype", &cpuSubType, &subSize, NULL, 0);
    if(res != 0){
        cpuSubType = 0;
    }
    return [FTPresetProperty CPUArchForMajor:cpuType minor:cpuSubType];
}
+ (NSString*)CPUArchForMajor:(cpu_type_t)majorCode minor:(cpu_subtype_t)minorCode{
#ifdef __APPLE__
    // In Apple platforms we can use this function to get the name of a particular architecture
    const NXArchInfo* info = NXGetArchInfoFromCpuType(majorCode, minorCode);
    if (info && info->name) {
        return [[NSString alloc] initWithUTF8String: info->name];
    }
#endif

    switch(majorCode)
    {
        case CPU_TYPE_ARM:
        {
            switch (minorCode)
            {
                case CPU_SUBTYPE_ARM_V6:
                    return @"armv6";
                case CPU_SUBTYPE_ARM_V7:
                    return @"armv7";
                case CPU_SUBTYPE_ARM_V7F:
                    return @"armv7f";
                case CPU_SUBTYPE_ARM_V7K:
                    return @"armv7k";
#ifdef CPU_SUBTYPE_ARM_V7S
                case CPU_SUBTYPE_ARM_V7S:
                    return @"armv7s";
#endif
            }
            return @"arm";
        }
        case CPU_TYPE_ARM64:
        {
            switch (minorCode)
            {
                case CPU_SUBTYPE_ARM64E:
                    return @"arm64e";
            }
            return @"arm64";
        }
        case CPU_TYPE_X86:
            return @"i386";
        case CPU_TYPE_X86_64:
            return @"x86_64";
    }
    return [NSString stringWithFormat:@"unknown(%d,%d)", majorCode, minorCode];
}
+ (NSString *)deviceInfo{
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *platform = [NSString stringWithCString:systemInfo.machine encoding:NSASCIIStringEncoding];
#if TARGET_OS_IOS
    //------------------------------iPhone---------------------------
    if ([platform isEqualToString:@"iPhone18,4"]) return @"iPhone Air";
    if ([platform isEqualToString:@"iPhone18,3"]) return @"iPhone 17";
    if ([platform isEqualToString:@"iPhone18,2"]) return @"iPhone 17 Pro Max";
    if ([platform isEqualToString:@"iPhone18,1"]) return @"iPhone 17 Pro";
    if ([platform isEqualToString:@"iPhone17,5"]) return @"iPhone 16e";
    if ([platform isEqualToString:@"iPhone17,3"]) return @"iPhone 16";
    if ([platform isEqualToString:@"iPhone17,4"]) return @"iPhone 16 Plus";
    if ([platform isEqualToString:@"iPhone17,1"]) return @"iPhone 16 Pro";
    if ([platform isEqualToString:@"iPhone17,2"]) return @"iPhone 16 Pro Max";
    if ([platform isEqualToString:@"iPhone16,2"]) return @"iPhone 15 Pro Max";
    if ([platform isEqualToString:@"iPhone16,1"]) return @"iPhone 15 Pro";
    if ([platform isEqualToString:@"iPhone15,5"]) return @"iPhone 15 Plus";
    if ([platform isEqualToString:@"iPhone15,4"]) return @"iPhone 15";
    if ([platform isEqualToString:@"iPhone15,3"]) return @"iPhone 14 Pro Max";
    if ([platform isEqualToString:@"iPhone15,2"]) return @"iPhone 14 Pro";
    if ([platform isEqualToString:@"iPhone14,8"]) return @"iPhone 14 Plus";
    if ([platform isEqualToString:@"iPhone14,7"]) return @"iPhone 14";
    if ([platform isEqualToString:@"iPhone14,3"]) return @"iPhone 13 Pro Max";
    if ([platform isEqualToString:@"iPhone14,2"]) return @"iPhone 13 Pro";
    if ([platform isEqualToString:@"iPhone14,5"]) return @"iPhone 13";
    if ([platform isEqualToString:@"iPhone14,4"]) return @"iPhone 13 mini";
    if ([platform isEqualToString:@"iPhone13,4"]) return @"iPhone 12 Pro Max";
    if ([platform isEqualToString:@"iPhone13,3"]) return @"iPhone 12 Pro";
    if ([platform isEqualToString:@"iPhone13,2"]) return @"iPhone 12";
    if ([platform isEqualToString:@"iPhone13,1"]) return @"iPhone 12 mini";
    if ([platform isEqualToString:@"iPhone12,8"]) return @"iPhone SE 2";
    if ([platform isEqualToString:@"iPhone12,5"]) return @"iPhone 11 Pro Max";
    if ([platform isEqualToString:@"iPhone12,3"]) return @"iPhone 11 Pro";
    if ([platform isEqualToString:@"iPhone12,1"]) return @"iPhone 11";
    if ([platform isEqualToString:@"iPhone11,8"]) return @"iPhone XR";
    if ([platform isEqualToString:@"iPhone11,6"]) return @"iPhone XS MAX";
    if ([platform isEqualToString:@"iPhone11,4"]) return @"iPhone XS MAX";
    if ([platform isEqualToString:@"iPhone11,2"]) return @"iPhone XS";
    if ([platform isEqualToString:@"iPhone10,6"]) return @"iPhone X";
    if ([platform isEqualToString:@"iPhone10,3"]) return @"iPhone X";
    if ([platform isEqualToString:@"iPhone10,5"]) return @"iPhone 8 Plus";
    if ([platform isEqualToString:@"iPhone10,2"]) return @"iPhone 8 Plus";
    if ([platform isEqualToString:@"iPhone10,4"]) return @"iPhone 8";
    if ([platform isEqualToString:@"iPhone10,1"]) return @"iPhone 8";
    if ([platform isEqualToString:@"iPhone9,4"]) return @"iPhone 7 Plus";
    if ([platform isEqualToString:@"iPhone9,2"]) return @"iPhone 7 Plus";
    if ([platform isEqualToString:@"iPhone9,3"]) return @"iPhone 7";
    if ([platform isEqualToString:@"iPhone9,1"]) return @"iPhone 7";
    if ([platform isEqualToString:@"iPhone8,4"]) return @"iPhone SE 1";
    if ([platform isEqualToString:@"iPhone8,2"]) return @"iPhone 6s Plus";
    if ([platform isEqualToString:@"iPhone8,1"]) return @"iPhone 6s";
    if ([platform isEqualToString:@"iPhone7,2"]) return @"iPhone 6";
    if ([platform isEqualToString:@"iPhone7,1"]) return @"iPhone 6 Plus";
    if ([platform isEqualToString:@"iPhone6,2"]) return @"iPhone 5s";
    if ([platform isEqualToString:@"iPhone6,1"]) return @"iPhone 5s";
    if ([platform isEqualToString:@"iPhone5,4"]) return @"iPhone 5c";
    if ([platform isEqualToString:@"iPhone5,3"]) return @"iPhone 5c";
    if ([platform isEqualToString:@"iPhone5,2"]) return @"iPhone 5";
    if ([platform isEqualToString:@"iPhone5,1"]) return @"iPhone 5";
    if ([platform isEqualToString:@"iPhone4,1"]) return @"iPhone 4S";
    if ([platform isEqualToString:@"iPhone3,3"]) return @"iPhone 4";
    if ([platform isEqualToString:@"iPhone3,2"]) return @"iPhone 4";
    if ([platform isEqualToString:@"iPhone3,1"]) return @"iPhone 4";
    if ([platform isEqualToString:@"iPhone2,1"]) return @"iPhone 3GS";
    if ([platform isEqualToString:@"iPhone1,2"]) return @"iPhone 3G";
    if ([platform isEqualToString:@"iPhone1,1"]) return @"iPhone 2G";
    
    
    //------------------------------iPad--------------------------
    if ([platform isEqualToString:@"iPad1,1"])  return @"iPad 1";
    if ([platform isEqualToString:@"iPad2,1"])  return @"iPad 2";
    if ([platform isEqualToString:@"iPad2,2"]) return @"iPad 2";
    if ([platform isEqualToString:@"iPad2,3"])  return @"iPad 2";
    if ([platform isEqualToString:@"iPad2,4"])  return @"iPad 2";
    if ([platform isEqualToString:@"iPad2,5"])  return @"iPad Mini 1";
    if ([platform isEqualToString:@"iPad2,6"])  return @"iPad Mini 1";
    if ([platform isEqualToString:@"iPad2,7"])  return @"iPad Mini 1";
    if ([platform isEqualToString:@"iPad3,1"])  return @"iPad 3";
    if ([platform isEqualToString:@"iPad3,2"])  return @"iPad 3";
    if ([platform isEqualToString:@"iPad3,3"])  return @"iPad 3";
    if ([platform isEqualToString:@"iPad3,4"])  return @"iPad 4";
    if ([platform isEqualToString:@"iPad3,5"])  return @"iPad 4";
    if ([platform isEqualToString:@"iPad3,6"])  return @"iPad 4";
    if ([platform isEqualToString:@"iPad4,1"])  return @"iPad Air";
    if ([platform isEqualToString:@"iPad4,2"])  return @"iPad Air";
    if ([platform isEqualToString:@"iPad4,3"])  return @"iPad Air";
    if ([platform isEqualToString:@"iPad4,4"])  return @"iPad mini 2";
    if ([platform isEqualToString:@"iPad4,5"])  return @"iPad mini 2";
    if ([platform isEqualToString:@"iPad4,6"])  return @"iPad mini 2";
    if ([platform isEqualToString:@"iPad4,7"])  return @"iPad mini 3";
    if ([platform isEqualToString:@"iPad4,8"])  return @"iPad mini 3";
    if ([platform isEqualToString:@"iPad4,9"])  return @"iPad mini 3";
    if ([platform isEqualToString:@"iPad5,1"])  return @"iPad mini 4";
    if ([platform isEqualToString:@"iPad5,2"])  return @"iPad mini 4";
    if ([platform isEqualToString:@"iPad5,3"])  return @"iPad Air 2";
    if ([platform isEqualToString:@"iPad5,4"])  return @"iPad Air 2";
    if ([platform isEqualToString:@"iPad6,3"])  return @"iPad Pro (9.7-inch)";
    if ([platform isEqualToString:@"iPad6,4"])  return @"iPad Pro (9.7-inch)";
    if ([platform isEqualToString:@"iPad6,7"])  return @"iPad Pro (12.9-inch)";
    if ([platform isEqualToString:@"iPad6,8"])  return @"iPad Pro (12.9-inch)";
    if ([platform isEqualToString:@"iPad6,11"])  return @"iPad 5";
    if ([platform isEqualToString:@"iPad6,12"])  return @"iPad 5";
    if ([platform isEqualToString:@"iPad7,1"])  return @"iPad Pro 2(12.9-inch)";
    if ([platform isEqualToString:@"iPad7,2"])  return @"iPad Pro 2(12.9-inch)";
    if ([platform isEqualToString:@"iPad7,3"])  return @"iPad Pro (10.5-inch)";
    if ([platform isEqualToString:@"iPad7,4"])  return @"iPad Pro (10.5-inch)";
    if ([platform isEqualToString:@"iPad7,5"])  return @"iPad 6";
    if ([platform isEqualToString:@"iPad7,6"])  return @"iPad 6";
    if ([platform isEqualToString:@"iPad7,11"])  return @"iPad 7";
    if ([platform isEqualToString:@"iPad7,12"])  return @"iPad 7";
    if ([platform isEqualToString:@"iPad8,1"])  return @"iPad Pro (11-inch) ";
    if ([platform isEqualToString:@"iPad8,2"])  return @"iPad Pro (11-inch) ";
    if ([platform isEqualToString:@"iPad8,3"])  return @"iPad Pro (11-inch) ";
    if ([platform isEqualToString:@"iPad8,4"])  return @"iPad Pro (11-inch) ";
    if ([platform isEqualToString:@"iPad8,5"])  return @"iPad Pro 3 (12.9-inch) ";
    if ([platform isEqualToString:@"iPad8,6"])  return @"iPad Pro 3 (12.9-inch) ";
    if ([platform isEqualToString:@"iPad8,7"])  return @"iPad Pro 3 (12.9-inch) ";
    if ([platform isEqualToString:@"iPad8,8"])  return @"iPad Pro 3 (12.9-inch) ";
    if ([platform isEqualToString:@"iPad8,9"])  return @"iPad Pro 2 (11-inch) ";
    if ([platform isEqualToString:@"iPad8,10"])  return @"iPad Pro 2 (11-inch) ";
    if ([platform isEqualToString:@"iPad8,11"])  return @"iPad Pro 4 (12.9-inch) ";
    if ([platform isEqualToString:@"iPad8,12"])  return @"iPad Pro 4 (12.9-inch) ";
    if ([platform isEqualToString:@"iPad11,1"])  return @"iPad mini 5";
    if ([platform isEqualToString:@"iPad11,2"])  return @"iPad mini 5";
    if ([platform isEqualToString:@"iPad11,3"])  return @"iPad Air 3";
    if ([platform isEqualToString:@"iPad11,4"])  return @"iPad Air 3";
    if ([platform isEqualToString:@"iPad11,6"])  return @"iPad 8";
    if ([platform isEqualToString:@"iPad11,7"])  return @"iPad 8";
    if ([platform isEqualToString:@"iPad12,1"])  return @"iPad 9";
    if ([platform isEqualToString:@"iPad12,2"])  return @"iPad 9";
    if ([platform isEqualToString:@"iPad13,1"])  return @"iPad Air 4";
    if ([platform isEqualToString:@"iPad13,2"])  return @"iPad Air 4";
    if ([platform isEqualToString:@"iPad13,4"])  return @"iPad Pro 3 (11-inch) ";
    if ([platform isEqualToString:@"iPad13,5"])  return @"iPad Pro 3 (11-inch) ";
    if ([platform isEqualToString:@"iPad13,6"])  return @"iPad Pro 3 (11-inch) ";
    if ([platform isEqualToString:@"iPad13,7"])  return @"iPad Pro 3 (11-inch) ";
    if ([platform isEqualToString:@"iPad13,8"])  return @"iPad Pro 5 (12.9-inch) ";
    if ([platform isEqualToString:@"iPad13,9"])  return @"iPad Pro 5 (12.9-inch) ";
    if ([platform isEqualToString:@"iPad13,10"])  return @"iPad Pro 5 (12.9-inch) ";
    if ([platform isEqualToString:@"iPad13,11"])  return @"iPad Pro 5 (12.9-inch) ";
    if ([platform isEqualToString:@"iPad13,16"])   return @"iPad Air 5";
    if ([platform isEqualToString:@"iPad13,17"])   return @"iPad Air 5";
    if ([platform isEqualToString:@"iPad13,18"])  return @"iPad 10";
    if ([platform isEqualToString:@"iPad13,19"])  return @"iPad 10";
    if ([platform isEqualToString:@"iPad14,1"])  return @"iPad mini 6";
    if ([platform isEqualToString:@"iPad14,2"])  return @"iPad mini 6";
    if ([platform isEqualToString:@"iPad14,3"]) return @"iPad Pro 4_11";
    if ([platform isEqualToString:@"iPad14,4"]) return @"iPad Pro 4_11";
    if ([platform isEqualToString:@"iPad14,5"]) return @"iPad Pro 6_12.9";
    if ([platform isEqualToString:@"iPad14,6"]) return @"iPad Pro 6_12.9";
    if ([platform isEqualToString:@"iPad14,8"]) return @"iPad Air M2_11";
    if ([platform isEqualToString:@"iPad14,9"]) return @"iPad Air M2_11";
    if ([platform isEqualToString:@"iPad14,10"])   return @"iPad Air M2_13";
    if ([platform isEqualToString:@"iPad14,11"])   return @"iPad Air M2_13";
    if ([platform isEqualToString:@"iPad16,3"]) return @"iPad Pro M4_11";
    if ([platform isEqualToString:@"iPad16,4"]) return @"iPad Pro M4_11";
    if ([platform isEqualToString:@"iPad16,5"]) return @"iPad Pro M4_13";
    if ([platform isEqualToString:@"iPad16,6"]) return @"iPad Pro M4_13";
    
    //------------------------------iTouch------------------------
    if ([platform isEqualToString:@"iPod1,1"]) return @"iTouch";
    if ([platform isEqualToString:@"iPod2,1"]) return @"iTouch2";
    if ([platform isEqualToString:@"iPod3,1"]) return  @"iTouch3";
    if ([platform isEqualToString:@"iPod4,1"]) return  @"iTouch4";
    if ([platform isEqualToString:@"iPod5,1"]) return  @"iTouch5";
    if ([platform isEqualToString:@"iPod7,1"]) return  @"iTouch6";
   
    //------------------------------Samulitor----------------------------------
    if ([platform isEqualToString:@"i386"] ||
        [platform isEqualToString:@"x86_64"] || [platform isEqualToString:@"arm64"]){
        return  @"iPhone Simulator";
    }
#elif TARGET_OS_TV
    if ([platform isEqualToString:@"AppleTV1,1"]) return @"Apple TV (1st generation)";
    if ([platform isEqualToString:@"AppleTV2,1"]) return @"Apple TV (2nd generation)";
    if ([platform isEqualToString:@"AppleTV3,1"]||[platform isEqualToString:@"AppleTV3,2"]) return @"Apple TV (3rd generation)";
    if ([platform isEqualToString:@"AppleTV5,3"]) return @"Apple TV (4th generation)";
    if ([platform isEqualToString:@"AppleTV6,2"]) return @"Apple TV 4K";
    if ([platform isEqualToString:@"AppleTV11,1"]) return @"Apple TV 4K (2nd generation)";
    if ([platform isEqualToString:@"AppleTV14,1"]) return @"Apple TV 4K (3rd generation)";
   //------------------------------Samulitor----------------------------------
    if ([platform isEqualToString:@"i386"] ||
        [platform isEqualToString:@"x86_64"] || [platform isEqualToString:@"arm64"]){
        return  @"AppleTV Simulator";
    }
#endif
    return platform;
}
#if FT_HOST_MAC
+ (NSString *)getDeviceUUID{
    io_registry_entry_t ioRegistryRoot = IORegistryEntryFromPath(kIOMasterPortDefault, "IOService:/");
    CFStringRef uuidCf = (CFStringRef) IORegistryEntryCreateCFProperty(ioRegistryRoot, CFSTR(kIOPlatformUUIDKey), kCFAllocatorDefault, 0);
    IOObjectRelease(ioRegistryRoot);
    NSString * uuid = (__bridge NSString *)uuidCf;
    CFRelease(uuidCf);
    return uuid;
}
+ (NSString *)macOSDeviceModel {
    NSString *macDevTypeStr = @"Unknown Mac";//Device model
    size_t len = 0;
    sysctlbyname("hw.model", NULL, &len, NULL, 0);
    if (len) {
        NSMutableData *data = [NSMutableData dataWithLength:len];
        sysctlbyname("hw.model", [data mutableBytes], &len, NULL, 0);
        macDevTypeStr = [NSString stringWithUTF8String:[data bytes]];
        NSDictionary *deviceNamesByCode = @{
            //MacBook Pro
            @"Mac14,5":@"MacBook Pro (14-inch, 2023)",
            @"Mac14,9":@"MacBook Pro (14-inch, 2023)",
            @"Mac14,6":@"MacBook Pro (16-inch, 2023)",
            @"Mac14,10":@"MacBook Pro (16-inch, 2023)",
            @"Mac14,7":@"MacBook Pro (13-inch, M2, 2022)",
            @"MacBookPro18,3":@"MacBook Pro (14-inch, 2021)",
            @"MacBookPro18,4":@"MacBook Pro (14-inch, 2021)",
            @"MacBookPro18,1":@"MacBook Pro (16-inch, 2021)",
            @"MacBookPro18,2":@"MacBook Pro (16-inch, 2021)",
            @"MacBookPro17,1":@"MacBook Pro (13-inch, M1, 2020)",
            @"MacBookPro16,3":@"MacBook Pro (13-inch, 2020, two Thunderbolt 3 ports)",
            @"MacBookPro16,2":@"MacBook Pro (13-inch, 2020, four Thunderbolt 3 ports)",
            @"MacBookPro16,1":@"MacBook Pro (16-inch, 2019)",
            @"MacBookPro16,4":@"MacBook Pro (16-inch, 2019)",
            @"MacBookPro15,4":@"MacBook Pro (13-inch, 2019, two Thunderbolt 3 ports)",
            @"MacBookPro15,1":@"MacBook Pro (15-inch, 2019/2018)",
            @"MacBookPro15,3":@"MacBook Pro (15-inch, 2019)",
            @"MacBookPro15,2":@"MacBook Pro (13-inch, 2019/2018, four Thunderbolt 3 ports)",
            @"MacBookPro14,3":@"MacBook Pro (15-inch, 2017)",
            @"MacBookPro14,2":@"MacBook Pro (13-inch, 2017, four Thunderbolt 3 ports)",
            @"MacBookPro14,1":@"MacBook Pro (13-inch, 2017, two Thunderbolt 3 ports)",
            @"MacBookPro13,3":@"MacBook Pro (15-inch, 2016)",
            @"MacBookPro13,2":@"MacBook Pro (13-inch, 2016, four Thunderbolt 3 ports)",
            @"MacBookPro13,1":@"MacBook Pro (13-inch, 2016, two Thunderbolt 3 ports)",
            @"MacBookPro11,4":@"MacBook Pro (Retina, 15-inch, Mid 2015)",
            @"MacBookPro11,5":@"MacBook Pro (Retina, 15-inch, Mid 2015)",
            @"MacBookPro12,1":@"MacBook Pro (Retina, 13-inch, Early 2015)",
            @"MacBookPro11,2":@"MacBook Pro (Retina, 15-inch, Mid 2014/Late 2013)",
            @"MacBookPro11,3":@"MacBook Pro (Retina, 15-inch, Mid 2014/Late 2013)",
            @"MacBookPro11,1":@"MacBook Pro (Retina, 13-inch, Mid 2014/Late 2013)",
            @"MacBookPro10,1":@"MacBook Pro (Retina,  15-inch, Early 2013/Mid 2012)",
            @"MacBookPro10,2":@"MacBook Pro (Retina, 13-inch, 2013/2012)",
            @"MacBookPro9,1":@"MacBook Pro (15-inch, Mid 2012)",
            @"MacBookPro9,2":@"MacBook Pro (13-inch, Mid 2012)",
            @"MacBookPro8,3":@"MacBook Pro (17-inch, 2011)",
            @"MacBookPro8,2":@"MacBook Pro (15-inch, 2011)",
            @"MacBookPro8,1":@"MacBook Pro (13-inch, 2011)",
            @"MacBookPro6,1":@"MacBook Pro (17-inch, Mid 2010)",
            @"MacBookPro6,2":@"MacBook Pro (15-inch, Mid 2010)",
            @"MacBookPro7,1":@"MacBook Pro (13-inch, Mid 2010)",
            //MacBook
            @"MacBook10,1":@"MacBook (Retina, 12-inch, 2017)",
            @"MacBook9,1":@"MacBook (Retina Display, 12-inch, Early 2016)",
            @"MacBook8,1":@"MacBook (Retina, 12-inch, Early 2015)",
            @"MacBook7,1":@"MacBook (13-inch, Mid 2010)",
            @"MacBook6,1":@"MacBook (13-inch, Late 2009)",
            @"MacBook5,2":@"MacBook (13-inch, 2009)",
            //MacBook Air
            @"Mac14,2":@"MacBook Air (M2, 2022)",
            @"MacBookAir10,1":@"MacBook Air (M1, 2020)",
            @"MacBookAir9,1":@"MacBook Air (Retina, 13-inch, 2020)",
            @"MacBookAir8,2":@"MacBook Air (Retina, 13-inch, 2019)",
            @"MacBookAir8,1":@"MacBook Air (Retina Display, 13-inch, 2018)",
            @"MacBookAir7,2":@"MacBook Air (13-inch, 2017/Early 2015)",
            @"MacBookAir7,1":@"MacBook Air (11-inch, Early 2015)",
            @"MacBookAir6,2":@"MacBook Air (13-inch, Mid 2013/Early 2014)",
            @"MacBookAir6,1":@"MacBook Air (11-inch, Mid 2013/Early 2014)",
            @"MacBookAir5,2":@"MacBook Air (13-inch, Mid 2012)",
            @"MacBookAir5,1":@"MacBook Air (11-inch, Mid 2012)",
            @"MacBookAir4,2":@"MacBook Air (13-inch, Mid 2011)",
            @"MacBookAir4,1":@"MacBook Air (11-inch, Mid 2011)",
            @"MacBookAir3,2":@"MacBook Air (13-inch, Late 2010)",
            @"MacBookAir3,1":@"MacBook Air (11-inch, Late 2010)",
            @"MacBookAir2,1":@"MacBook Air (Mid 2009)",
            //Mac Pro
            @"MacPro7,1":@"Mac Pro (2019)",
            @"MacPro7,1Technical":@"Mac Pro (Rackmount, 2019)",
            @"MacPro6,1":@"Mac Pro (Late 2013)",
            @"MacPro5,1":@"Mac Pro Server/Mac Pro (Mid 2010)",
            //iMac
            @"iMac21,1":@"iMac (24-inch, M1, 2021)",
            @"iMac21,2":@"iMac (24-inch, M1, 2021)",
            @"iMac20,1":@"iMac (Retina 5K Display, 27-inch, 2020)",
            @"iMac20,2":@"iMac (Retina 5K Display, 27-inch, 2020)",
            @"iMac19,1":@"iMac (Retina 5K Display, 27-inch, 2019)",
            @"iMac19,2":@"iMac (Retina 4K Display, 21.5-inch, 2019)",
            @"iMacPro1,1":@"iMac Pro",
            @"iMac18,3":@"iMac (Retina 5K Display, 27-inch, 2017)",
            @"iMac18,2":@"iMac (Retina 4K Display, 21.5-inch, 2017)",
            @"iMac18,1":@"iMac (21.5-inch, 2017)",
            @"iMac17,1":@"iMac (Retina 5K Display, 27-inch, Late 2015)",
            @"iMac16,2":@"iMac (Retina 4K, 21.5-inch, Late 2015)",
            @"iMac16,1":@"iMac (21.5-inch, Late 2015)",
            @"iMac15,1":@"iMac (Retina 5K, 27-in, Late 2014/Mid 2015)",
            @"iMac14,4":@"iMac (21.5-inch, Mid 2014)",
            @"iMac14,2":@"iMac (27-inch, Late 2013)",
            @"iMac14,1":@"iMac (21.5-inch, Late 2013)",
            @"iMac13,2":@"iMac (27-inch, Late 2012)",
            @"iMac13,1":@"iMac (21.5-inch, Late 2012)",
            @"iMac12,2":@"iMac (27-inch, Mid 2011)",
            @"iMac12,1":@"iMac (21.5-inch, Mid 2011)",
            @"iMac11,3":@"iMac (27-inch, Mid 2010)",
            @"iMac11,2":@"iMac (21.5-inch, Mid 2010)",
            @"iMac10,1":@"iMac (27-inch/21.5-inch, Late 2009)",
            //Mac mini
            @"Mac14,3":@"The Mac mini (2023)",
            @"Mac14,12":@"The Mac mini (2023)",
            @"Macmini9,1":@"Mac mini (M1, 2020)",
            @"Macmini8,1":@"Mac mini (2018)",
            @"Macmini7,1":@"Mac mini (Late 2014)",
            @"Macmini6,1":@"Mac mini (Late 2012)",
            @"Macmini6,2":@"Mac mini (Late 2012)",
            @"Macmini5,1":@"Mac mini (Mid 2011)",
            @"Macmini5,2":@"Mac mini (Mid 2011)",
            @"Macmini4,1":@"Mac mini (Mid 2010)",
        };
        NSString* deviceName = [deviceNamesByCode objectForKey:macDevTypeStr];
        if (deviceName) {
            macDevTypeStr = deviceNamesByCode[macDevTypeStr];
        }
    }
    return macDevTypeStr;
}
#endif

+ (NSString *)getOSVersion{
#if FT_HAS_UIKIT
    return  [UIDevice currentDevice].systemVersion;
#else
    NSOperatingSystemVersion version = [NSProcessInfo processInfo].operatingSystemVersion;
    ;
    NSString *systemVersion;
    if (version.patchVersion == 0) {
        systemVersion = [NSString stringWithFormat:@"%d.%d", (int)version.majorVersion, (int)version.minorVersion];
    } else {
        systemVersion = [NSString stringWithFormat:@"%d.%d.%d", (int)version.majorVersion,
                                                   (int)version.minorVersion, (int)version.patchVersion];
    }
    return systemVersion;
#endif
}
- (void)shutDown{
    [self safeWrite:^{
        self->_basePropertyModel = nil;
        self->_rumPropertyModel = nil;
        self->_logPropertyModel = nil;
        self->_rumScreenSizeResolved = NO;
        self->_dataModifier = nil;
        self->_lineDataModifier = nil;
        self->_sessionReplayTags = nil;
    }];
}
@end
