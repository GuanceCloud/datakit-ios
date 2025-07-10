//
//  FTPresetProperty.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/10/23.
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
#import "FTLog.h"
#include <mach-o/arch.h>
#include <sys/sysctl.h>
#if FT_MAC
#import <AppKit/AppKit.h>
#import <IOKit/IOKitLib.h>
#endif

@interface MobileDevice : NSObject
@property (nonatomic,copy,readonly) NSString *os;
@property (nonatomic,copy,readonly) NSString *device;
@property (nonatomic,copy,readonly) NSString *model;
@property (nonatomic,copy,readonly) NSString *deviceUUID;
@property (nonatomic,copy,readonly) NSString *osVersion;
@property (nonatomic,copy,readonly) NSString *osVersionMajor;
@property (nonatomic,copy,readonly) NSString *screenSize;
@property (nonatomic,copy,readonly) NSString *cpuArch;
@end
@implementation MobileDevice
-(instancetype)init{
    self = [super init];
    if (self) {
        _device = @"APPLE";
#if FT_HAS_UIKIT
        _model = [FTPresetProperty deviceInfo];
        _deviceUUID =[[UIDevice currentDevice] identifierForVendor].UUIDString;
        CGFloat scale = [[UIScreen mainScreen] scale];
        CGRect rect = [[UIScreen mainScreen] bounds];
        _screenSize = [[NSString alloc] initWithFormat:@"%.f*%.f",rect.size.height*scale,rect.size.width*scale];
        _os = [UIDevice currentDevice].systemName;
        
#elif FT_MAC
        _os = @"macOS";
        NSRect rect = [NSScreen mainScreen].frame;
        _screenSize =[[NSString alloc] initWithFormat:@"%.f*%.f",rect.size.height,rect.size.width];
        _deviceUUID = [FTPresetProperty getDeviceUUID];
        _model = [FTPresetProperty macOSDeviceModel];
#endif
        _cpuArch = [FTPresetProperty cpuArch];
        _osVersion = [FTPresetProperty getOSVersion];
        _osVersionMajor = [_osVersion stringByDeletingPathExtension];
    }
    return self;
}
@end
@interface FTPresetProperty ()
/// device basic info
@property (nonatomic, strong) MobileDevice *mobileDevice;
@property (nonatomic, strong) NSDictionary *baseCommonPropertyTags;
@property (nonatomic, strong) NSDictionary *rumGlobalContext;
@property (nonatomic, strong, readwrite) NSDictionary *loggerTags;
@property (nonatomic, strong, readwrite) NSDictionary *rumStaticFields;
@property (nonatomic, copy) FTDataModifier dataModifier;
@property (nonatomic, copy) NSString *rumCustomKeys;

@property (nonatomic, strong, readwrite) NSMutableDictionary *rumTags;
@property (nonatomic, strong) NSMutableDictionary *globalContext;
@property (nonatomic, strong) NSMutableDictionary *globalRUMContext;
@property (nonatomic, strong) NSMutableDictionary *globalLogContext;
@property (nonatomic, strong) FTUserInfo *userInfo;

@property (nonatomic, strong) dispatch_queue_t concurrentQueue;
@end
@implementation FTPresetProperty
@synthesize baseCommonPropertyTags = _baseCommonPropertyTags;
@synthesize rumGlobalContext = _rumGlobalContext;
@synthesize loggerTags = _loggerTags;
@synthesize rumStaticFields = _rumStaticFields;
@synthesize dataModifier = _dataModifier;
@synthesize lineDataModifier = _lineDataModifier;
@synthesize rumCustomKeys = _rumCustomKeys;
@synthesize rumTags = _rumTags;
@synthesize globalContext = _globalContext;
@synthesize globalRUMContext = _globalRUMContext;
@synthesize globalLogContext = _globalLogContext;
@synthesize userInfo = _userInfo;

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
    if(self){
        _mobileDevice = [[MobileDevice alloc]init];
        _concurrentQueue = dispatch_queue_create("com.guance.readwrite", DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}
- (void)start{
    self.rumTags = [NSMutableDictionary dictionary];
    self.userInfo = [FTUserInfo new];
    self.globalContext = [NSMutableDictionary new];
    self.globalRUMContext = [NSMutableDictionary new];
    self.globalLogContext = [NSMutableDictionary new];
}
// sdkConfig
- (void)startWithVersion:(NSString *)version
              sdkVersion:(NSString *)sdkVersion
                     env:(NSString *)env
                 service:(NSString *)service
           globalContext:(NSDictionary *)globalContext
                 pkgInfo:(NSDictionary *)pkgInfo{
    [self start];
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setValue:[self getApplicationUUID] forKey:FT_APPLICATION_UUID];
    [dict setValue:self.mobileDevice.deviceUUID forKey:FT_COMMON_PROPERTY_DEVICE_UUID];
    [dict setValue:service forKey:FT_KEY_SERVICE];
    [dict setValue:version forKey:FT_VERSION];
    [dict setValue:env forKey:FT_ENV];
    [dict addEntriesFromDictionary:globalContext];
    [dict setValue:pkgInfo forKey:FT_SDK_PKG_INFO];
    [dict setValue:sdkVersion forKey:FT_SDK_VERSION];
    NSDictionary *newDict = [self applyModifier:dict];
    self.baseCommonPropertyTags = newDict;
}
#pragma mark ----property setter/getter thread safe ----
-(void)setBaseCommonPropertyTags:(NSDictionary *)baseCommonPropertyTags{
    dispatch_barrier_async(self.concurrentQueue, ^{
        self->_baseCommonPropertyTags = baseCommonPropertyTags;
    });
}
-(NSDictionary *)baseCommonPropertyTags{
    __block NSDictionary *obj;
    dispatch_sync(self.concurrentQueue, ^{
        obj = [self->_baseCommonPropertyTags copy];
    });
    return obj;
}
-(void)setRumGlobalContext:(NSDictionary *)rumGlobalContext{
    dispatch_barrier_async(self.concurrentQueue, ^{
        self->_rumGlobalContext = rumGlobalContext;
    });
}
-(NSDictionary *)rumGlobalContext{
    __block NSDictionary *obj;
    dispatch_sync(self.concurrentQueue, ^{
        obj = [self->_rumGlobalContext copy];
    });
    return obj;
}
-(void)setLoggerTags:(NSDictionary *)loggerTags{
    dispatch_barrier_async(self.concurrentQueue, ^{
        self->_loggerTags = loggerTags;
    });
}
-(NSDictionary *)loggerTags{
    __block NSDictionary *obj;
    dispatch_sync(self.concurrentQueue, ^{
        obj = [self->_loggerTags copy];
    });
    return obj;
}
-(void)setRumStaticFields:(NSDictionary *)rumStaticFields{
    dispatch_barrier_async(self.concurrentQueue, ^{
        self->_rumStaticFields = rumStaticFields;
    });
}
-(NSDictionary *)rumStaticFields{
    __block NSDictionary *obj;
    dispatch_sync(self.concurrentQueue, ^{
        obj = [self->_rumStaticFields copy];
    });
    return obj;
}
-(void)setDataModifier:(FTDataModifier)dataModifier{
    dispatch_barrier_async(self.concurrentQueue, ^{
        self->_dataModifier = dataModifier;
    });
}
-(FTDataModifier)dataModifier{
    __block FTDataModifier obj;
    dispatch_sync(self.concurrentQueue, ^{
        obj = [self->_dataModifier copy];
    });
    return obj;
}
-(void)setLineDataModifier:(FTLineDataModifier)lineDataModifier{
    dispatch_barrier_async(self.concurrentQueue, ^{
        self->_lineDataModifier = lineDataModifier;
    });
}
-(FTLineDataModifier)lineDataModifier{
    __block FTDataModifier obj;
    dispatch_sync(self.concurrentQueue, ^{
        obj = [self->_lineDataModifier copy];
    });
    return obj;
}
-(void)setRumCustomKeys:(NSString *)rumCustomKeys{
    dispatch_barrier_async(self.concurrentQueue, ^{
        self->_rumCustomKeys = rumCustomKeys;
    });
}
- (NSString *)rumCustomKeys{
    __block NSString *obj;
    dispatch_sync(self.concurrentQueue, ^{
        obj = [self->_rumCustomKeys copy];
    });
    return obj;
}
-(void)setRumTags:(NSMutableDictionary *)rumTags{
    dispatch_barrier_async(self.concurrentQueue, ^{
        self->_rumTags = rumTags;
    });
}
-(NSMutableDictionary *)rumTags{
    __block NSMutableDictionary *obj;
    dispatch_sync(self.concurrentQueue, ^{
        obj = [self->_rumTags copy];
    });
    return obj;
}
-(void)setGlobalContext:(NSMutableDictionary *)globalContext{
    dispatch_barrier_async(self.concurrentQueue, ^{
        self->_globalContext = globalContext;
    });
}
-(NSMutableDictionary *)globalContext{
    __block NSMutableDictionary *obj;
    dispatch_sync(self.concurrentQueue, ^{
        obj = [self->_globalContext copy];
    });
    return obj;
}
-(void)setGlobalLogContext:(NSMutableDictionary *)globalLogContext{
    dispatch_barrier_async(self.concurrentQueue, ^{
        self->_globalLogContext = globalLogContext;
    });
}
-(NSMutableDictionary *)globalLogContext{
    __block NSMutableDictionary *obj;
    dispatch_sync(self.concurrentQueue, ^{
        obj = [self->_globalLogContext copy];
    });
    return obj;
}
-(void)setGlobalRUMContext:(NSMutableDictionary *)globalRUMContext{
    dispatch_barrier_async(self.concurrentQueue, ^{
        self->_globalRUMContext = globalRUMContext;
    });
}
-(NSMutableDictionary *)globalRUMContext{
    __block NSMutableDictionary *obj;
    dispatch_sync(self.concurrentQueue, ^{
        obj = [self->_globalRUMContext copy];
    });
    return obj;
}
- (void)concurrentWrite:(void (^)(void))block{
    dispatch_barrier_async(self.concurrentQueue, ^{
        block();
    });
}
#pragma mark ---- api ----
-(void)setDataModifier:(FTDataModifier )dataModifier lineDataModifier:(FTLineDataModifier)lineDataModifier{
    self.dataModifier = dataModifier;
    self.lineDataModifier = lineDataModifier;
}
-(void)updateUser:(NSString *)Id name:(NSString *)name email:(NSString *)email extra:(NSDictionary *)extra{
    [self concurrentWrite:^{
        [self->_userInfo updateUser:Id name:name email:email extra:extra];
    }];
}
-(void)clearUser{
    [self concurrentWrite:^{
        [self->_userInfo clearUser];
    }];
}
// rumTags
- (void)setRUMAppID:(NSString *)appID sampleRate:(int)sampleRate sessionOnErrorSampleRate:(int)sessionOnErrorSampleRate rumGlobalContext:(NSDictionary *)rumGlobalContext{
    _rumGlobalContext = rumGlobalContext;
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[FT_COMMON_PROPERTY_DEVICE] = self.mobileDevice.device;
    dict[FT_COMMON_PROPERTY_DEVICE_MODEL] = self.mobileDevice.model;
    dict[FT_COMMON_PROPERTY_OS] = self.mobileDevice.os;
    dict[FT_COMMON_PROPERTY_OS_VERSION] = self.mobileDevice.osVersion;
    dict[FT_COMMON_PROPERTY_OS_VERSION_MAJOR] = self.mobileDevice.osVersionMajor;
    dict[FT_SCREEN_SIZE] = self.mobileDevice.screenSize;
    dict[FT_CPU_ARCH] = self.mobileDevice.cpuArch;
    dict[FT_SDK_NAME] = FT_SDK_NAME_VALUE;
    [dict setValue:appID forKey:FT_APP_ID];
    [dict addEntriesFromDictionary:rumGlobalContext];
    NSDictionary *newDict = [self applyModifier:dict];
    
    self.rumStaticFields = @{FT_RUM_SESSION_SAMPLE_RATE:@(sampleRate),
                         FT_RUM_SESSION_ON_ERROR_SAMPLE_RATE:@(sessionOnErrorSampleRate),
    };
    [self concurrentWrite:^{
        [self->_rumTags addEntriesFromDictionary:self->_baseCommonPropertyTags];
        [self->_rumTags addEntriesFromDictionary:newDict];
    }];
   
    if(rumGlobalContext&&rumGlobalContext.count>0){
        self.rumCustomKeys = [FTJSONUtil convertToJsonDataWithObject:rumGlobalContext.allKeys];
    }
}
-(void)setLogGlobalContext:(NSDictionary *)logGlobalContext{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict addEntriesFromDictionary:self.baseCommonPropertyTags];
    NSDictionary *newDict = [self applyModifier:logGlobalContext];
    [dict addEntriesFromDictionary:newDict];
    self.loggerTags = dict;
}
- (NSDictionary *)loggerDynamicTags{
    NSMutableDictionary *tag = [NSMutableDictionary new];
    [tag addEntriesFromDictionary:self.globalContext];
    [tag addEntriesFromDictionary:self.globalLogContext];
    return tag;
}
- (NSDictionary *)rumDynamicTags{
    NSMutableDictionary *dict = [NSMutableDictionary new];
    [dict addEntriesFromDictionary:self.globalContext];
    [dict addEntriesFromDictionary:self.globalRUMContext];
    [dict setValue:self.rumCustomKeys forKey:FT_RUM_CUSTOM_KEYS];
    // user
    FTUserInfo *user = self.userInfo;
    dict[FT_USER_ID] = user.userId;
    dict[FT_USER_NAME] = user.name;
    dict[FT_USER_EMAIL] = user.email;
    [dict setValue:user.isSignIn?@"T":@"F" forKey:FT_IS_SIGNIN];
    if (user.extra) {
        [dict addEntriesFromDictionary:user.extra];
    }
    return dict;
}
- (void)appendGlobalContext:(NSDictionary *)context{
    if(context && context.count>0){
        NSDictionary *newContext = [self applyModifier:context];
        [self concurrentWrite:^{
            [self->_globalContext addEntriesFromDictionary:newContext];
        }];
    }
}
- (void)appendRUMGlobalContext:(NSDictionary *)context{
    if(context && context.count>0){
        NSDictionary *newContext = [self applyModifier:context];
        [self concurrentWrite:^{
            [self->_globalRUMContext addEntriesFromDictionary:newContext];
            NSMutableArray *allKeys = [NSMutableArray arrayWithArray:self->_globalRUMContext.allKeys];
            if(self->_rumGlobalContext.count>0){
                [allKeys addObjectsFromArray:self->_rumGlobalContext.allKeys];
            }
            self->_rumCustomKeys = [FTJSONUtil convertToJsonDataWithObject:allKeys];
        }];
    }
}
- (void)appendLogGlobalContext:(NSDictionary *)context{
    if(context && context.count>0){
        NSDictionary *newContext = [self applyModifier:context];
        [self concurrentWrite:^{
            [self->_globalLogContext addEntriesFromDictionary:newContext];
        }];
    }
}
- (NSDictionary *)applyModifier:(NSDictionary *)dict{
    if (self.dataModifier == nil || dict == nil) return dict;
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    [dict enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        id value = self.dataModifier(key, obj);
        if (value) {
            [result setValue:value forKey:key];
        }else{
            [result setValue:obj forKey:key];
        }
    }];
    return result;
}

- (NSArray<NSDictionary *> *)applyLineModifier:(NSString *)measurement
                                         tags:(NSDictionary *)tags
                                       fields:(NSDictionary *)fields {
    // 快速终止条件：lineDataModifier 为 nil 时直接返回原始数据（防御性处理）
    if (!self.lineDataModifier) {
        return @[ tags ? [tags copy] : @{},
                 fields ? [fields copy] : @{} ];
    }

    // 创建安全的可变副本（兼容 tags/fields 为 nil 的情况）
    NSMutableDictionary *mutableTags = tags ? [tags mutableCopy] : [NSMutableDictionary dictionary];
    NSMutableDictionary *mutableFields = fields ? [fields mutableCopy] : [NSMutableDictionary dictionary];
    
    NSMutableDictionary *mergedValues = [NSMutableDictionary dictionary];
    if (mutableTags.count > 0) [mergedValues addEntriesFromDictionary:mutableTags];
    if (mutableFields.count > 0) [mergedValues addEntriesFromDictionary:mutableFields];
    
    // 执行 Block 并校验返回值
    NSDictionary *changedValues = self.lineDataModifier(measurement, [mergedValues copy]);
    if (changedValues.count == 0) {
        return @[ [mutableTags copy], [mutableFields copy] ];
    }
    [changedValues enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if (mutableTags[key]) {
            mutableTags[key] = obj;
        } else if (mutableFields[key]) {
            mutableFields[key] = obj;
        }
    }];
    
    return @[ [mutableTags copy], [mutableFields copy] ];
}
- (NSString *)getApplicationUUID{
    // 获取 image 的 index
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
            // 根据 index 获取 header
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
//// 获取 Load Command
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
#if FT_MAC
+ (NSString *)getDeviceUUID{
    io_registry_entry_t ioRegistryRoot = IORegistryEntryFromPath(kIOMasterPortDefault, "IOService:/");
    CFStringRef uuidCf = (CFStringRef) IORegistryEntryCreateCFProperty(ioRegistryRoot, CFSTR(kIOPlatformUUIDKey), kCFAllocatorDefault, 0);
    IOObjectRelease(ioRegistryRoot);
    NSString * uuid = (__bridge NSString *)uuidCf;
    CFRelease(uuidCf);
    return uuid;
}
+ (NSString *)macOSDeviceModel {
    NSString *macDevTypeStr = @"Unknown Mac";//设备型号
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
    self.baseCommonPropertyTags = nil;
    self.rumGlobalContext = nil;
    self.loggerTags = nil;
    self.rumStaticFields = nil;
    self.dataModifier = nil;
    self.lineDataModifier = nil;
    self.rumCustomKeys = nil;
    self.rumTags = nil;
    self.globalContext = nil;
    self.globalRUMContext = nil;
    self.globalLogContext = nil;
    self.userInfo = nil;
}
@end

