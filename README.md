# FT Mobile SDK iOS

## 安装
-  **通过源码集成**
   - 获取源码。
   - 将 SDK 源代码导入 App 项目，并选中 Copy items if needed;
   - 添加依赖库：项目设置 "Build Phase" -> "Link Binary With Libraries" 添加：libicucore、libsqlite3 和 libz。
-  **通过 CocoaPods 集成**
  - 配置Podfile文件，在Podfile文件中添加`pod 'FTAutoTrack'`
  - 在 Podfile 目录下执行 pod install 安装 SDK。
 
## 配置
- 添加头文件
请将`#import <FTMobileAgent/FTMobileAgent.h>
`添加到 AppDelegate.m 引用头文件的位置。

- 添加初始化代码
  请将以下代码添加到`-(BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions`
  
  ```objective-c
    FTMobileConfig *config = [FTMobileConfig new];
    config.enableRequestSigning = YES;
    config.akSecret = akSecret;
    config.akId = akId;
    config.isDebug = YES;
    config.metricsUrl = 写入地址;
    [FTMobileAgent startWithConfigOptions:config];
``` 

### SDK 可配置参数
| 字段 | 类型 |说明|是否必须|
|:--------:|:--------:|:--------:|:--------:|
|  enableRequestSigning      |  BOOL      |配置是否需要进行请求签名  |是|
|metricsUrl|NSString|FT-GateWay metrics 写入地址|是|
|akId|NSString|access key ID| enableRequestSigning 为 true 时，必须要填|
|akSecret|NSString|access key Secret|enableRequestSigning 为 true 时，必须要填|
|isDebug|BOOL|设置是否允许打印日志|否（默认NO）|

## 方法
 1、FT SDK公开了2个埋点方法，用户通过这三个方法可以主动在需要的地方实现埋点，然后将数据上传到服务端。

-  方法一：

```objective-c
  /**
追踪自定义事件。
 @param field      文件名称（必填）
 @param values     事件名称（必填）
*/ 
 - (void)track:( NSString *)field  values:(NSDictionary *)values;
```
 
-  方法二：

```objective-c
/**
 追踪自定义事件。
 
 @param field      文件名称（必填）
 @param tags       事件属性（选填）
 @param values     事件名称（必填）
 */
 - (void)track:( NSString *)field tags:(nullable NSDictionary*)tags values:( NSDictionary *)values;
```

2、方法使用示例

```objective-c
   [[FTMobileAgent sharedInstance] track:@"home.operation" tags:@{@"pushVC":@"SecondViewController"} values:@{@"event":@"BtnClick"}];
   
```


## 常见问题
