//
//  FTPresetProperty.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/10/23.
//  Copyright © 2020 hll. All rights reserved.
//

#import "FTPresetProperty.h"
#import "FTBaseInfoHandler.h"
#import "FTMobileAgentVersion.h"
#import <sys/utsname.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>
//设备对象 __class 值
static NSString * const FT_OBJECT_DEFAULT_CLASS = @"Mobile_Device";
//系统版本
static NSString * const FT_COMMON_PROPERTY_OS_VERSION = @"os_version";
//操作系统主要版本
static NSString * const FT_COMMON_PROPERTY_OS_VERSION_MAJOR = @"os_version_major";

//是否是注册用户，属性值：True / False
static NSString * const FT_IS_SIGNIN = @"is_signin";
static NSString * const FT_USERID = @"userid";
static NSString * const FT_ORIGIN_ID = @"origin_id";
//操作系统
static NSString * const FT_COMMON_PROPERTY_OS = @"os";
//设备提供商
static NSString * const FT_COMMON_PROPERTY_DEVICE = @"device";
//本地语言
static NSString * const FT_COMMON_PROPERTY_LOCALE = @"locale";
//分辨率，格式 height * width，例子：1920*1080
static NSString * const FT_COMMON_PROPERTY_DISPLAY = @"display";
//运营商
static NSString * const FT_COMMON_PROPERTY_CARRIER = @"carrier";
//agent 版本号
static NSString * const FT_COMMON_PROPERTY_AGENT = @"agent";
//autotrack 版本号
static NSString * const FT_COMMON_PROPERTY_AUTOTRACK = @"autoTrack";
//应用名称
static NSString * const FT_COMMON_PROPERTY_APP_NAME = @"app_name";
//设备机型
static NSString * const FT_COMMON_PROPERTY_DEVICE_MODEL = @"model";
//屏幕宽度
static NSString * const FT_SCREEN_SIZE = @"screen_size";
//设备 UUID
static NSString * const FT_COMMON_PROPERTY_DEVICE_UUID = @"device_uuid";
//应用 ID
static NSString * const FT_COMMON_PROPERTY_APP_IDENTIFIER = @"app_identifiedid";

static NSString * const FT_ENV = @"env";
static NSString * const FT_VERSION = @"version";
static NSString * const FT_SDK_VERSION = @"sdk_version";
static NSString * const FT_APP_ID = @"app_id";
static NSString * const FTBaseInfoHanderDeviceType = @"FTBaseInfoHanderDeviceType";
static NSString * const FT_SDK_NAME = @"sdk_name";

@interface MobileDevice : NSObject
@property (nonatomic,copy,readonly) NSString *os;
@property (nonatomic,copy,readonly) NSString *device;
@property (nonatomic,copy,readonly) NSString *model;
@property (nonatomic,copy,readonly) NSString *deviceUUID;
@property (nonatomic,copy,readonly) NSString *osVersion;
@property (nonatomic,copy,readonly) NSString *osVersionMajor;
@property (nonatomic,copy,readonly) NSString *screenSize;
@end
@implementation MobileDevice
-(instancetype)init{
    self = [super init];
    if (self) {
        _os = @"iOS";
        _device = @"APPLE";
        _model = [FTPresetProperty deviceInfo];
        _deviceUUID =[[UIDevice currentDevice] identifierForVendor].UUIDString;
        _osVersion = [UIDevice currentDevice].systemVersion;
        _osVersionMajor = [[UIDevice currentDevice].systemVersion stringByDeletingPathExtension];
        CGFloat scale = [[UIScreen mainScreen] scale];
        CGRect rect = [[UIScreen mainScreen] bounds];
        _screenSize =[[NSString alloc] initWithFormat:@"%.f*%.f",rect.size.height*scale,rect.size.width*scale];
    }
    return self;
}
@end
@interface FTPresetProperty ()
@property (nonatomic, strong) MobileDevice *mobileDevice;
@property (nonatomic, strong) NSMutableDictionary *webCommonPropertyTags;
@property (nonatomic, strong) NSMutableDictionary *rumCommonPropertyTags;
@property (nonatomic, strong) NSDictionary *baseCommonPropertyTags;
@property (nonatomic, copy) NSString *version;
@property (nonatomic, copy) NSString *env;
@end
@implementation FTPresetProperty
- (instancetype)initWithVersion:(NSString *)version env:(NSString *)env{
    self = [super init];
    if (self) {
        _version = version;
        _env = env;
        _isSignin = [FTBaseInfoHandler userId]?YES:NO;
        _mobileDevice = [[MobileDevice alloc]init];
    }
    return self;
}
-(NSMutableDictionary *)webCommonPropertyTags{
    if(!_webCommonPropertyTags){
        @synchronized (self) {
            if (!_webCommonPropertyTags) {
                _webCommonPropertyTags = [[NSMutableDictionary alloc]init];
                _webCommonPropertyTags[FT_COMMON_PROPERTY_OS] = self.mobileDevice.os;
                _webCommonPropertyTags[FT_COMMON_PROPERTY_OS_VERSION] = self.mobileDevice.osVersion;
                _webCommonPropertyTags[FT_SCREEN_SIZE] = self.mobileDevice.screenSize;
            }
        }
    }
    return _webCommonPropertyTags;
}
-(NSMutableDictionary *)rumCommonPropertyTags{
    if (!_rumCommonPropertyTags) {
        @synchronized (self) {
            if (!_rumCommonPropertyTags) {
                _rumCommonPropertyTags = [NSMutableDictionary new];
                _rumCommonPropertyTags[FT_COMMON_PROPERTY_DEVICE] = self.mobileDevice.device;
                _rumCommonPropertyTags[FT_COMMON_PROPERTY_DEVICE_MODEL] = self.mobileDevice.model;
                _rumCommonPropertyTags[FT_COMMON_PROPERTY_OS] = self.mobileDevice.os;
                _rumCommonPropertyTags[FT_COMMON_PROPERTY_OS_VERSION] = self.mobileDevice.osVersion;
                _rumCommonPropertyTags[FT_COMMON_PROPERTY_OS_VERSION_MAJOR] = self.mobileDevice.osVersionMajor;
                _rumCommonPropertyTags[FT_COMMON_PROPERTY_DEVICE_UUID] = self.mobileDevice.deviceUUID;
                _rumCommonPropertyTags[FT_SCREEN_SIZE] = self.mobileDevice.screenSize;
                _rumCommonPropertyTags[FT_SDK_VERSION] = SDK_VERSION;
            }
        }
        
    }
    return _rumCommonPropertyTags;
}
-(NSDictionary *)baseCommonPropertyTags{
    if (!_baseCommonPropertyTags) {
        @synchronized (self) {
            if (!_baseCommonPropertyTags) {
                _baseCommonPropertyTags =@{@"application_identifier":[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"],
                                           @"device_uuid":[[UIDevice currentDevice] identifierForVendor].UUIDString,
                };
            }
        }
    }
    return _baseCommonPropertyTags;
}
- (NSDictionary *)loggerPropertyWithStatus:(FTStatus)status serviceName:(NSString *)serviceName{
    NSMutableDictionary *tag = [NSMutableDictionary dictionaryWithDictionary:self.baseCommonPropertyTags];
    [tag setValue:[FTBaseInfoHandler statusStrWithStatus:status] forKey:FT_KEY_STATUS];
    [tag setValue:self.version forKey:@"version"];
    [tag setValue:serviceName forKey:FT_KEY_SERVICE];
    return tag;
}
- (NSDictionary *)traceProperty{
    NSMutableDictionary *tag = [NSMutableDictionary dictionaryWithDictionary:self.baseCommonPropertyTags];
    [tag setValue:self.version forKey:@"version"];
    return tag;
}
- (void)resetWithVersion:(NSString *)version env:(NSString *)env{
    self.version = version;
    self.env = env;
    _isSignin = [FTBaseInfoHandler userId]?YES:NO;
}
- (NSDictionary *)rumPropertyWithTerminal:(NSString *)terminal{
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:self.rumCommonPropertyTags];
    dict[FT_SDK_NAME] = [terminal isEqualToString:@"app"]?@"df_ios_rum_sdk":@"df_web_rum_sdk";
    dict[@"userid"] = [FTPresetProperty userid];
    [dict setValue:self.env forKey:FT_ENV];
    [dict setValue:self.version forKey:FT_VERSION];
    [dict setValue:self.appid forKey:FT_APP_ID];
    [dict setValue:[self isSigninStr] forKey:FT_IS_SIGNIN];
    return dict;
}
-(void)setIsSignin:(BOOL)isSignin{
    _isSignin = isSignin;
}
- (NSString *)isSigninStr{
    return _isSignin?@"T":@"F";
}
+ (NSString *)deviceInfo{
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *platform = [NSString stringWithCString:systemInfo.machine encoding:NSASCIIStringEncoding];
    //------------------------------iPhone---------------------------
    if ([platform isEqualToString:@"iPhone1,1"]){
        return @"iPhone 2G";
    }
    if ([platform isEqualToString:@"iPhone1,2"]){
        return @"iPhone 3G";
    }
    if ([platform isEqualToString:@"iPhone2,1"]){
        return @"iPhone 3GS";
    }
    if ([platform isEqualToString:@"iPhone3,1"] ||
        [platform isEqualToString:@"iPhone3,2"] ||
        [platform isEqualToString:@"iPhone3,3"]){
        return @"iPhone 4";
    }
    if ([platform isEqualToString:@"iPhone4,1"]){
        return @"iPhone 4S";
    }
    if ([platform isEqualToString:@"iPhone5,1"] ||
        [platform isEqualToString:@"iPhone5,2"]){
        return @"iPhone 5";
    }
    if ([platform isEqualToString:@"iPhone5,3"] ||
        [platform isEqualToString:@"iPhone5,4"]){
        return @"iPhone 5c";
    }
    if ([platform isEqualToString:@"iPhone6,1"] ||
        [platform isEqualToString:@"iPhone6,2"] ||
        [platform isEqualToString:@"iPhone6,3"]){
        return @"iPhone 5s";
    }
    if ([platform isEqualToString:@"iPhone7,2"]){
        return @"iPhone 6";
    }
    if ([platform isEqualToString:@"iPhone7,1"]){
        return @"iPhone 6 Plus";
    }
    if ([platform isEqualToString:@"iPhone8,1"]){
        return @"iPhone 6s";
    }
    if ([platform isEqualToString:@"iPhone8,2"]){
        return @"iPhone 6s Plus";
    }
    if ([platform isEqualToString:@"iPhone8,4"]){
        return @"iPhone SE";
    }
    if ([platform isEqualToString:@"iPhone9,1"] ||
        [platform isEqualToString:@"iPhone9,3"]){
        return @"iPhone 7";
    }
    if ([platform isEqualToString:@"iPhone9,2"] ||
        [platform isEqualToString:@"iPhone9,4"]){
        return @"iPhone 7 Plus";
    }
    if ([platform isEqualToString:@"iPhone10,1"] ||
        [platform isEqualToString:@"iPhone10,4"]){
        return @"iPhone 8";
    }
    if ([platform isEqualToString:@"iPhone10,2"] ||
        [platform isEqualToString:@"iPhone10,5"]){
        return @"iPhone 8 Plus";
    }
    if ([platform isEqualToString:@"iPhone10,3"] ||
        [platform isEqualToString:@"iPhone10,6"]){
        return @"iPhone X";
    }
    if ([platform isEqualToString:@"iPhone11,8"]){
        return @"iPhone XR";
    }
    if ([platform isEqualToString:@"iPhone11,2"]){
        return @"iPhone XS";
    }
    if ([platform isEqualToString:@"iPhone11,4"] ||
        [platform isEqualToString:@"iPhone11,6"]){
        return @"iPhone XS Max";
    }
    if ([platform isEqualToString:@"iPhone12,1"]){
        return @"iPhone 11";
    }
    if ([platform isEqualToString:@"iPhone12,3"]){
        return @"iPhone 11 Pro";
    }
    if ([platform isEqualToString:@"iPhone12,5"]){
        return @"iPhone 11 Pro Max";
    }
    if ([platform isEqualToString:@"iPhone12,8"]) {
        return @"iPhone SE 2";
    }
    if ([platform isEqualToString:@"iPhone13,1"]) {
        return @"iPhone 12 mini";
    }
    if ([platform isEqualToString:@"iPhone13,2"]) {
        return @"iPhone 12";
    }
    if ([platform isEqualToString:@"iPhone13,3"]) {
        return @"iPhone 12 Pro";
    }
    if ([platform isEqualToString:@"iPhone13,4"]) {
        return @"iPhone 12 Pro Max";
    }
    //------------------------------iPad--------------------------
    if ([platform isEqualToString:@"iPad1,1"]){
        return @"iPad";
    }
    if ([platform isEqualToString:@"iPad2,1"] ||
        [platform isEqualToString:@"iPad2,2"] ||
        [platform isEqualToString:@"iPad2,3"] ||
        [platform isEqualToString:@"iPad2,4"]){
        return @"iPad 2";
    }
    if ([platform isEqualToString:@"iPad3,1"] ||
        [platform isEqualToString:@"iPad3,2"] ||
        [platform isEqualToString:@"iPad3,3"]){
        return @"iPad 3";
    }
    if ([platform isEqualToString:@"iPad3,4"] ||
        [platform isEqualToString:@"iPad3,5"] ||
        [platform isEqualToString:@"iPad3,6"]){
        return @"iPad 4";
    }
    if ([platform isEqualToString:@"iPad4,1"] ||
        [platform isEqualToString:@"iPad4,2"] ||
        [platform isEqualToString:@"iPad4,3"]){
        return @"iPad Air";
    }
    if ([platform isEqualToString:@"iPad5,3"] ||
        [platform isEqualToString:@"iPad5,4"]){
        return @"iPad Air 2";
    }
    if ([platform isEqualToString:@"iPad6,3"] ||
        [platform isEqualToString:@"iPad6,4"]){
        return @"iPad Pro 9.7-inch";
    }
    if ([platform isEqualToString:@"iPad6,7"] ||
        [platform isEqualToString:@"iPad6,8"]){
        return @"iPad Pro 12.9-inch";
    }
    if ([platform isEqualToString:@"iPad6,11"] ||
        [platform isEqualToString:@"iPad6,12"]){
        return @"iPad 5";
    }
    if ([platform isEqualToString:@"iPad7,5"] ||
        [platform isEqualToString:@"iPad7,6"]){
        return @"iPad 6";
    }
    if ([platform isEqualToString:@"iPad7,11"] ||
        [platform isEqualToString:@"iPad7,12"]){
        return @"iPad 7";
    }
    if ([platform isEqualToString:@"iPad7,1"] ||
        [platform isEqualToString:@"iPad7,2"]){
        return @"iPad Pro 12.9-inch 2";
    }
    if ([platform isEqualToString:@"iPad7,3"] ||
        [platform isEqualToString:@"iPad7,4"]){
        return @"iPad Pro 10.5-inch";
    }
    if ([platform isEqualToString:@"iPad8,5"] ||
        [platform isEqualToString:@"iPad8,6"] ||
        [platform isEqualToString:@"iPad8,7"] ||
        [platform isEqualToString:@"iPad8,8"]){
        return @"iPad Pro 12.9-inch 3";
    }
    if ([platform isEqualToString:@"iPad8,1"] ||
        [platform isEqualToString:@"iPad8,2"] ||
        [platform isEqualToString:@"iPad8,3"] ||
        [platform isEqualToString:@"iPad8,4"]){
        return @"iPad Pro 11.0-inch";
    }
    if ([platform isEqualToString:@"iPad11,3"] ||
        [platform isEqualToString:@"iPad11,4"]){
        return @"iPad Air 3";
    }
    if ([platform isEqualToString:@"iPad11,6"] ||
        [platform isEqualToString:@"iPad11,7"]){
        return @"iPad 8";
    }
    if ([platform isEqualToString:@"iPad13,1"] ||
        [platform isEqualToString:@"iPad13,2"]){
        return @"iPad Air 4";
    }
    
    //------------------------------iPad Mini-----------------------
    if ([platform isEqualToString:@"iPad2,5"] ||
        [platform isEqualToString:@"iPad2,6"] ||
        [platform isEqualToString:@"iPad2,7"]){
        return  @"iPad mini";
    }
    if ([platform isEqualToString:@"iPad4,4"] ||
        [platform isEqualToString:@"iPad4,5"] ||
        [platform isEqualToString:@"iPad4,6"]){
        return @"iPad mini 2";
    }
    if ([platform isEqualToString:@"iPad4,7"] ||
        [platform isEqualToString:@"iPad4,8"] ||
        [platform isEqualToString:@"iPad4,9"]){
        return  @"iPad mini 3";
    }
    if ([platform isEqualToString:@"iPad5,1"] ||
        [platform isEqualToString:@"iPad5,2"]){
        return  @"iPad mini 4";
    }
    if ([platform isEqualToString:@"iPad11,1"] ||
        [platform isEqualToString:@"iPad11,2"]){
        return @"iPad mini 5";
    }
    
    //------------------------------iTouch------------------------
    if ([platform isEqualToString:@"iPod1,1"]){
        return  @"iTouch";
    }
    if ([platform isEqualToString:@"iPod2,1"]){
        return @"iTouch2";
    }
    if ([platform isEqualToString:@"iPod3,1"]){
        return  @"iTouch3";
    }
    if ([platform isEqualToString:@"iPod4,1"]){
        return  @"iTouch4";
    }
    if ([platform isEqualToString:@"iPod5,1"]){
        return  @"iTouch5";
    }
    if ([platform isEqualToString:@"iPod7,1"]){
        return  @"iTouch6";
    }
    //------------------------------Samulitor-------------------------------------
    if ([platform isEqualToString:@"i386"] ||
        [platform isEqualToString:@"x86_64"]){
        return  @"iPhone Simulator";
    }
    return platform;
}
+(NSString *)telephonyInfo
{
    CTTelephonyNetworkInfo *info = [[CTTelephonyNetworkInfo alloc] init];
    CTCarrier *carrier;
    if (@available(iOS 12.0, *)) {
        if (info && [info respondsToSelector:@selector(serviceSubscriberCellularProviders)]) {
            NSDictionary *dic = [info serviceSubscriberCellularProviders];
            if (dic.allKeys.count) {
                carrier = [dic objectForKey:dic.allKeys[0]];
            }
        }
    }else{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        // 这部分使用到的过期api
        carrier= [info subscriberCellularProvider];
#pragma clang diagnostic pop
        
    }
    if(carrier ==nil){
        return FT_NULL_VALUE;
    }else{
        NSString *mCarrier = [NSString stringWithFormat:@"%@",[carrier carrierName]];
        return mCarrier;
    }
}
+ (NSString *)appIdentifier{
    NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
    return [infoDictionary objectForKey:@"CFBundleIdentifier"];
}
+ (NSString *)userid{
    NSString *useridStr = [FTBaseInfoHandler userId];
    if (!useridStr) {
        useridStr = [FTBaseInfoHandler sessionId];
    }
    return  useridStr;
}
@end

