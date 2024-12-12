//
//  FTPresetProperty.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/10/23.
//  Copyright © 2020 hll. All rights reserved.
//
#import "FTPresetProperty.h"
#import "FTBaseInfoHandler.h"
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
#if FT_MAC
        _os = @"macOS";
        NSRect rect = [NSScreen mainScreen].frame;
        _screenSize =[[NSString alloc] initWithFormat:@"%.f*%.f",rect.size.height,rect.size.width];
        _deviceUUID = [FTPresetProperty getDeviceUUID];
        _model = [FTPresetProperty macOSdeviceModel];
        _osVersion = [FTPresetProperty macOSSystermVersion];
        _osVersionMajor = [_osVersion stringByDeletingPathExtension];
#else
        _model = [FTPresetProperty deviceInfo];
        _os = @"iOS";
        _deviceUUID =[[UIDevice currentDevice] identifierForVendor].UUIDString;
        _osVersion = [UIDevice currentDevice].systemVersion;
        _osVersionMajor = [[UIDevice currentDevice].systemVersion stringByDeletingPathExtension];
        CGFloat scale = [[UIScreen mainScreen] scale];
        CGRect rect = [[UIScreen mainScreen] bounds];
        _screenSize =[[NSString alloc] initWithFormat:@"%.f*%.f",rect.size.height*scale,rect.size.width*scale];
        _cpuArch = [FTPresetProperty cpuArch];
#endif
    }
    return self;
}
@end
@interface FTPresetProperty ()
@property (nonatomic, strong) MobileDevice *mobileDevice;
@property (nonatomic, strong) NSMutableDictionary *rumCommonPropertyTags;
@property (nonatomic, strong) NSDictionary *baseCommonPropertyTags;
@property (nonatomic, copy) NSString *version;
@property (nonatomic, copy) NSString *env;
@property (nonatomic, copy) NSString *service;
@property (nonatomic, strong) FTReadWriteHelper<NSMutableDictionary*> *globalContextHelper;
@property (nonatomic, strong) FTReadWriteHelper<NSMutableDictionary*> *globalRUMContextHelper;
@property (nonatomic, strong) FTReadWriteHelper<NSMutableDictionary*> *globalLogContextHelper;
@property (nonatomic, strong) NSDictionary *globalContext;
@property (nonatomic, copy) NSString *rum_custom_keys;
@end
@implementation FTPresetProperty
static FTPresetProperty *sharedInstance = nil;
static dispatch_once_t onceToken;
+ (instancetype)sharedInstance{
    dispatch_once(&onceToken, ^{
        sharedInstance = [[FTPresetProperty alloc]init];
    });
    return sharedInstance;
}
-(instancetype)init{
    self = [super init];
    if(self){
        _mobileDevice = [[MobileDevice alloc]init];
        _userHelper = [[FTReadWriteHelper alloc]initWithValue:[FTUserInfo new]];
        _globalContextHelper = [[FTReadWriteHelper alloc]initWithValue:[NSMutableDictionary new]];
        _globalRUMContextHelper = [[FTReadWriteHelper alloc]initWithValue:[NSMutableDictionary new]];
        _globalLogContextHelper = [[FTReadWriteHelper alloc]initWithValue:[NSMutableDictionary new]];
    }
    return self;
}
- (void)startWithVersion:(NSString *)version sdkVersion:(NSString *)sdkVersion env:(NSString *)env service:(NSString *)service globalContext:(NSDictionary *)globalContext{
    _version = version;
    _env = env;
    _service = service;
    _sdkVersion = sdkVersion;
    _globalContext = globalContext;
}
-(void)setRumGlobalContext:(NSDictionary *)rumGlobalContext{
    _rumGlobalContext = rumGlobalContext;
    if(rumGlobalContext&&rumGlobalContext.count>0){
        self.rum_custom_keys = [FTJSONUtil convertToJsonDataWithObject:rumGlobalContext.allKeys];
    }
}
-(NSDictionary *)baseCommonPropertyTags{
    if (!_baseCommonPropertyTags) {
        @synchronized (self) {
            if (!_baseCommonPropertyTags) {
                _baseCommonPropertyTags =@{
                    FT_APPLICATION_UUID:[self getApplicationUUID],
                    FT_COMMON_PROPERTY_DEVICE_UUID:self.mobileDevice.deviceUUID,
                    FT_KEY_SERVICE:self.service,
                };
            }
        }
    }
    return _baseCommonPropertyTags;
}
- (NSDictionary *)loggerProperty{
    NSMutableDictionary *tag = [NSMutableDictionary new];
    [tag addEntriesFromDictionary:self.baseCommonPropertyTags];
    [tag setValue:self.version forKey:@"version"];
    [tag setValue:self.env forKey:FT_ENV];
    return tag;
}
- (NSDictionary *)loggerDynamicProperty{
    NSMutableDictionary *tag = [NSMutableDictionary new];
    [tag addEntriesFromDictionary:self.globalContextHelper.currentValue];
    [tag addEntriesFromDictionary:self.globalLogContextHelper.currentValue];
    [tag addEntriesFromDictionary:self.globalContext];
    [tag addEntriesFromDictionary:self.logGlobalContext];
    return tag;
}
- (NSMutableDictionary *)rumProperty{
    NSMutableDictionary *dict = [NSMutableDictionary new];
    // rum common property tags
    dict[FT_COMMON_PROPERTY_DEVICE] = self.mobileDevice.device;
    dict[FT_COMMON_PROPERTY_DEVICE_MODEL] = self.mobileDevice.model;
    dict[FT_COMMON_PROPERTY_OS] = self.mobileDevice.os;
    dict[FT_COMMON_PROPERTY_OS_VERSION] = self.mobileDevice.osVersion;
    dict[FT_COMMON_PROPERTY_OS_VERSION_MAJOR] = self.mobileDevice.osVersionMajor;
    dict[FT_COMMON_PROPERTY_DEVICE_UUID] = self.mobileDevice.deviceUUID;
    dict[FT_SCREEN_SIZE] = self.mobileDevice.screenSize;
    dict[FT_KEY_SERVICE] = self.service;
    dict[FT_SDK_VERSION] = self.sdkVersion;
    dict[FT_CPU_ARCH] = self.mobileDevice.cpuArch;
#if FT_MAC
    dict[FT_SDK_NAME] = FT_MACOS_SDK_NAME;
#else
    dict[FT_SDK_NAME] = FT_IOS_SDK_NAME;
#endif
    [dict setValue:self.env forKey:FT_ENV];
    [dict setValue:self.version forKey:FT_VERSION];
    [dict setValue:self.appID forKey:FT_APP_ID];
    return dict;
}
- (NSMutableDictionary *)rumWebViewProperty{
    NSMutableDictionary *dict = [NSMutableDictionary new];
    // rum common property tags
    dict[FT_COMMON_PROPERTY_DEVICE] = self.mobileDevice.device;
    dict[FT_COMMON_PROPERTY_DEVICE_MODEL] = self.mobileDevice.model;
    dict[FT_COMMON_PROPERTY_OS] = self.mobileDevice.os;
    dict[FT_COMMON_PROPERTY_OS_VERSION] = self.mobileDevice.osVersion;
    dict[FT_COMMON_PROPERTY_OS_VERSION_MAJOR] = self.mobileDevice.osVersionMajor;
    dict[FT_COMMON_PROPERTY_DEVICE_UUID] = self.mobileDevice.deviceUUID;
    dict[FT_SCREEN_SIZE] = self.mobileDevice.screenSize;
    dict[FT_CPU_ARCH] = self.mobileDevice.cpuArch;
    [dict setValue:self.env forKey:FT_ENV];
    [dict setValue:self.appID forKey:FT_APP_ID];
    [dict setValue:self.sdkVersion forKey:@"package_native"];
    return dict;
}
- (NSDictionary *)rumDynamicProperty{
    NSMutableDictionary *dict = [NSMutableDictionary new];
    [dict addEntriesFromDictionary:self.globalContextHelper.currentValue];
    [dict addEntriesFromDictionary:self.globalRUMContextHelper.currentValue];
    [dict addEntriesFromDictionary:self.globalContext];
    [dict addEntriesFromDictionary:self.rumGlobalContext];
    [dict setValue:self.rum_custom_keys forKey:FT_RUM_CUSTOM_KEYS];
    // user
    dict[FT_USER_ID] = self.userHelper.currentValue.userId;
    dict[FT_USER_NAME] = self.userHelper.currentValue.name;
    dict[FT_USER_EMAIL] = self.userHelper.currentValue.email;
    [dict setValue:[self isSignInStr] forKey:FT_IS_SIGNIN];
    if (self.userHelper.currentValue.extra) {
        [dict addEntriesFromDictionary:self.userHelper.currentValue.extra];
    }
    return dict;
}
- (void)appendGlobalContext:(NSDictionary *)context{
    if(context && context.count>0){
        [self.globalContextHelper concurrentWrite:^(NSMutableDictionary * _Nonnull value) {
            [value addEntriesFromDictionary:context];
        }];
    }
}
- (void)appendRUMGlobalContext:(NSDictionary *)context{
    if(context && context.count>0){
        __weak typeof(self) weakSelf = self;
        [self.globalRUMContextHelper concurrentWrite:^(NSMutableDictionary * _Nonnull value) {
            [value addEntriesFromDictionary:context];
            NSMutableArray *allKeys = [NSMutableArray arrayWithArray:value.allKeys];
            if(weakSelf.rumGlobalContext.count>0){
                [allKeys addObjectsFromArray:weakSelf.rumGlobalContext.allKeys];
            }
            weakSelf.rum_custom_keys = [FTJSONUtil convertToJsonDataWithObject:allKeys];
        }];
    }
}
- (void)appendLogGlobalContext:(NSDictionary *)context{
    if(context && context.count>0){
        [self.globalLogContextHelper concurrentWrite:^(NSMutableDictionary * _Nonnull value) {
            [value addEntriesFromDictionary:context];
        }];
    }
}
- (NSString *)isSignInStr{
    return self.userHelper.currentValue.isSignIn?@"T":@"F";
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
   
    //------------------------------Samulitor-------------------------------------
    if ([platform isEqualToString:@"i386"] ||
        [platform isEqualToString:@"x86_64"] || [platform isEqualToString:@"arm64"]){
        return  @"iPhone Simulator";
    }
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
+ (NSString *)macOSdeviceModel {
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
+ (NSString *)macOSSystermVersion{
    NSProcessInfo *info = [NSProcessInfo processInfo];
    NSInteger major = info.operatingSystemVersion.majorVersion;
    NSInteger minor = info.operatingSystemVersion.minorVersion;
    NSInteger patch = info.operatingSystemVersion.patchVersion;
    return  [NSString stringWithFormat:@"%ld.%ld.%ld",major,minor,patch];
}
#endif

- (void)shutDown{
    onceToken = 0;
    sharedInstance =nil;
}
@end

