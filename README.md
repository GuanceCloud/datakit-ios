
# Dataflux-SDK-iOS

Dataflux-SDK-iOS-Demo 链接: https://github.com/CloudCare/dataflux-sdk-ios-demo    

**FTMobileAgent**

![Cocoapods platforms](https://img.shields.io/cocoapods/p/FTMobileAgent)
![Cocoapods](https://img.shields.io/cocoapods/v/FTMobileAgent)
![Cocoapods](https://img.shields.io/cocoapods/l/FTMobileAgent)

**FTAutoTrack**

![Cocoapods platforms](https://img.shields.io/cocoapods/p/FTAutoTrack)
![Cocoapods](https://img.shields.io/cocoapods/v/FTAutoTrack)
![Cocoapods](https://img.shields.io/cocoapods/l/FTAutoTrack)


## 一、 导入SDK
   你可以使用下面方法进行导入：
###  方法1.直接下载下来安装
1.下载SDK。    
  配置下载链接：将想获取的 SDK 版本的版本号替换下载链接中的 VERSION。  
	 含全埋点的下载链接：https://zhuyun-static-files-production.oss-cn-hangzhou.aliyuncs.com/ft-sdk-package/ios/FTAutoTrack/VERSION.zip   
	 无全埋点的下载链接：https://zhuyun-static-files-production.oss-cn-hangzhou.aliyuncs.com/ft-sdk-package/ios/FTMobileAgent/VERSION.zip    
	 
2.将 SDK 源代码导入 App 项目，并选中 Copy items if needed 。

3.添加依赖库：项目设置 "Build Phase" -> "Link Binary With Libraries" 添加：`UIKit` 、 `Foundation` 、`libz.tbd`。
 
   
### 方式2.通过 CocoaPods 导入

1.配置 Podfile 文件。   
   如果需要全埋点功能，在 Podfile 文件中添加  `pod 'FTAutoTrack'`，不需要则
	 `pod 'FTMobileAgent'`    
	 
2.在 Podfile 目录下执行 pod install 安装 SDK。

## 二、初始化
1.添加头文件
请将 `#import <FTMobileAgent/FTMobileAgent.h>
` 添加到 AppDelegate.m 引用头文件的位置。    

2.添加初始化代码
  请将以下代码添加到 `-(BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions`
  eg:
  ```objective-c
     // SDK FTMobileConfig 设置
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:@"Your App metricsUrl" akId:@"Your App akId" akSecret: @"Your App akSecret" enableRequestSigning:YES];
    config.enableLog = YES;
    config.enableAutoTrack = YES;
    config.autoTrackEventType = FTAutoTrackEventTypeAppClick|FTAutoTrackEventTypeAppStart|FTAutoTrackEventTypeAppViewScreen;
    config.monitorInfoType = FTMonitorInfoTypeAll;
     //启动 SDK
    [FTMobileAgent startWithConfigOptions:config];
  ```     
      
	  



## 三、SDK 可配置参数
| 字段 | 类型 |说明|是否必须|
|:--------:|:--------:|:--------:|:--------:|
|  enableRequestSigning      |  BOOL      |配置是否需要进行请求签名  |是|
|metricsUrl|NSString|FT-GateWay metrics 写入地址|是|
|akId|NSString|access key ID| enableRequestSigning 为 true 时，必须要填|
|akSecret|NSString|access key Secret|enableRequestSigning 为 true 时，必须要填|
|enableLog|BOOL|设置是否允许打印日志|否（默认NO）|
|enableAutoTrack|BOOL|设置是否开启全埋点|否（默认NO）|
|autoTrackEventType|NS_OPTIONS|全埋点抓取事件枚举|否（默认FTAutoTrackTypeNone）|
|whiteViewClass|NSArray|UI控件白名单|否|
|blackViewClass|NSArray|UI控件黑名单|否|
|whiteVCList|NSArray|控制器白名单|否|
|blackVCList|NSArray|控制器黑名单|否|
|monitorInfoType|NS_OPTIONS|采集数据|否|

**关于GPU使用率获取**   
  获取GPU使用率，需要使用到 `IOKit.framework ` 私有库，**可能会影响AppStore上架**。如果需要此功能，需要在你的应用安装 `IOKit.framework ` 私有库。导入后，请在编译时加入 `FT_TRACK_GPUUSAGE` 标志，SDK将会为你获取GPU使用率。    
  XCode设置方法 :    
  
 ```
Build Settings > Apple LLVM 7.0 - Preprocessing > Processor Macros >
Release : FT_TRACK_GPUUSAGE=1
 ```

## 四、用户的绑定与注销 
 FT SDK 提供了绑定用户和注销用户的方法，只有在用户登录的状态下，进行数据的传输。
 1.用户绑定：
 
```
  /**
绑定用户信息
 @param name     用户名
 @param Id       用户Id
 @param exts     用户其他信息
*/
- (void)bindUserWithName:(NSString *)name Id:(NSString *)Id exts:(nullable NSDictionary *)exts;
```

2.用户注销：

```
/**
 注销当前用户
*/
- (void)logout;
```

3.方法使用示例

```
//登录后 绑定用户信息
    [[FTMobileAgent sharedInstance] bindUserWithName:userName Id:userId exts:nil];
```

```
//登出后 注销当前用户
    [[FTMobileAgent sharedInstance] logout];
```


## 五、埋点方法
 FT SDK 公开了2个埋点方法，用户通过这两个方法可以在需要的地方实现埋点，然后将数据上传到服务端。

1.方法一：

```objective-c
  /**
追踪自定义事件。
 @param field      指标（必填）
 @param values     指标值（必填）
*/ 
 - (void)track:( NSString *)field  values:(NSDictionary *)values;
```
 
2.方法二：

```objective-c
/**
 追踪自定义事件。
 
 @param field      指标（必填）
 @param tags       标签（选填）
 @param values     指标值（必填）
 */
 - (void)track:( NSString *)field tags:(nullable NSDictionary*)tags values:( NSDictionary *)values;
```

3.方法使用示例

```objective-c
   
[[FTMobileAgent sharedInstance] track:@"home.operation" tags:@{@"pushVC":@"SecondViewController"} values:@{@"event":@"BtnClick"}];
   
```


## 六、常见问题
**1.关于查询指标 IMEI**
- IMEI
   因为隐私问题，苹果用户在 iOS5 以后禁用代码直接获取 IMEI 的值。所以 iOS sdk 中不支持获取 IMEI。
   
