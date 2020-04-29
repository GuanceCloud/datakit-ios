
# Dataflux-SDK-iOS
[Dataflux-SDK-iOS-Demo](https://github.com/CloudCare/dataflux-sdk-ios-demo)   

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
### 1. 直接下载下来安装
1. 下载 SDK 。    
  配置下载链接：将想获取的 SDK 版本的版本号替换下载链接中的 **VERSION**。    
   + **含全埋点的下载链接：**    
https://zhuyun-static-files-production.oss-cn-hangzhou.aliyuncs.com/ft-sdk-package/ios/FTAutoTrack/_VERSION_.zip                
   + **无全埋点的下载链接：**    
https://zhuyun-static-files-production.oss-cn-hangzhou.aliyuncs.com/ft-sdk-package/ios/FTMobileAgent/_VERSION_.zip    
	 
2. 将 SDK 源代码导入 App 项目，并选中 `Copy items if needed`。
3.  添加依赖库：项目设置 `Build Phase` -> `Link Binary With Libraries` 添加：`UIKit` 、 `Foundation` 、`libz.tbd`。
 
   
### 2. 通过 CocoaPods 导入

1. 配置 `Podfile` 文件。    
    
  ```objective-c
   target 'yourProjectName' do

   # Pods for your project
   //如果需要全埋点功能
   pod 'FTAutoTrack'
   //不需要全埋点功能
   pod 'FTMobileAgent'
   
   end
  ```     
     
2. 在 `Podfile` 目录下执行 `pod install` 安装 SDK。

## 二、初始化 SDK
### 1. 添加头文件
请将 `#import <FTMobileAgent/FTMobileAgent.h>
` 添加到 `AppDelegate.m` 引用头文件的位置。    



### 2. 添加初始化代码
  示例：
  
```objective-c
 #import <FTMobileAgent/FTMobileAgent.h>
-(BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions{
     // SDK FTMobileConfig 设置
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:@"Your App metricsUrl" akId:@"Your App akId" akSecret: @"Your App akSecret" enableRequestSigning:YES];
    config.enableLog = YES;
    config.enableAutoTrack = YES;
    config.autoTrackEventType = FTAutoTrackEventTypeAppClick|FTAutoTrackEventTypeAppStart|FTAutoTrackEventTypeAppViewScreen;
    config.monitorInfoType = FTMonitorInfoTypeAll;
     //启动 SDK
    [FTMobileAgent startWithConfigOptions:config];
    return YES;
}
```     

## 三、FTMobileConfig 配置
### 1. FTMobileConfig 初始化方法    

  - 不需要进行签名配置    
     
    ```objective-c  
      /** 
        * @method 指定初始化方法，设置 metricsUrl 配置  不需要进行请求签名
        * @param metricsUrl FT-GateWay metrics 写入地址
        * @return 配置对象
      */
      - (instancetype)initWithMetricsUrl:(nonnull NSString *)metricsUrl;  
    ```    
	
  - 需要进行签名配置   
    
	```objective-c
      /**
        * @method 指定初始化方法，设置 metricsUrl
        * @param metricsUrl FT-GateWay metrics 写入地址
        * @param akId       access key ID
        * @param akSecret   access key Secret
        * @param enableRequestSigning 配置是否需要进行请求签名 为YES 时akId与akSecret 不能为空
        * @return 配置对象
      */
      - (instancetype)initWithMetricsUrl:(nonnull NSString *)metricsUrl akId:(nullable NSString *)akId akSecret:(nullable NSString *)akSecret enableRequestSigning:(BOOL)enableRequestSigning;
   ```
	
### 2.设置是否打印日志    

   在 **debug** 环境下，设置 `FTMobileConfig` 的 `enableLog` 属性。
   
   ```objective-c
    config.enableLog = YES; //打印日志
   ```    
### 3. 设置X-Datakit-UUID
 ` X-Datakit-UUID` 是 SDK 初始化生成的 UUID, 应用清理缓存后(包括应用删除)，会重新生成。
 `FTMobileConfig` 配置中，开发者可以强制更改。更改方法：
 
 ```objective-c
   [config setXDataKitUUID:@"YOUR UUID"];
 ```
  
### 4. 设置是否开启全埋点  
  
   开启全埋点，设置 `FTMobileConfig` 的 `enableAutoTrack = YES ;` 。
   在 `enableAutoTrack = YES ;` 的情况下，进行 `autoTrackEventType` 类型设置。    
   
```objective-c
/**
 * @enum
 * AutoTrack 抓取信息
 *
 * @constant
 *   FTAutoTrackEventTypeAppLaunch       - 项目启动
 *   FTAutoTrackEventTypeAppClick        - 点击事件
 *   FTAutoTrackEventTypeAppViewScreen   - 页面的生命周期 open/close
 */
typedef NS_OPTIONS(NSInteger, FTAutoTrackEventType) {
    FTAutoTrackTypeNone          = 0,
    FTAutoTrackEventTypeAppLaunch     = 1 << 0,
    FTAutoTrackEventTypeAppClick      = 1 << 1,
    FTAutoTrackEventTypeAppViewScreen = 1 << 2,
};
```
全埋点详细设置：[全埋点](#五全埋点)
  
### 5. 采集数据配置
    
   配置 `FTMobileConfig` 的 `FTMonitorInfoType` 属性。可采集的类型如下：    
   
 ```objective-c
  /**
 * @enum  TAG 中的设备信息
 *
 * @constant
 *   FTMonitorInfoTypeBattery  - 电池总量、使用量
 *   FTMonitorInfoTypeMemory   - 内存总量、使用率
 *   FTMonitorInfoTypeCpu      - CPU型号、占用率
 *   FTMonitorInfoTypeCpu      - GPU型号、占用率
 *   FTMonitorInfoTypeNetwork  - 网络的信号强度、网络速度、类型、代理
 *   FTMonitorInfoTypeCamera   - 前置/后置 像素
 *   FTMonitorInfoTypeLocation - 位置信息  国家、省、市、经纬度
 *   FTMonitorInfoTypeSystem   - 开机时间、设备名
 *   FTMonitorInfoTypeSensor   - 屏幕亮度、当天步数、距离传感器、陀螺仪三轴旋转角速度、三轴线性加速度、三轴地磁强度
 *   FTMonitorInfoTypeBluetooth- 蓝牙对外显示名称
 *   FTMonitorInfoTypeSensorBrightness - 屏幕亮度
 *   FTMonitorInfoTypeSensorStep       - 当天步数
 *   FTMonitorInfoTypeSensorProximity  - 距离传感器
 *   FTMonitorInfoTypeSensorRotation   - 陀螺仪三轴旋转角速度
 *   FTMonitorInfoTypeSensorAcceleration - 三轴线性加速度
 *   FTMonitorInfoTypeSensorMagnetic   - 三轴地磁强度
 *   FTMonitorInfoTypeSensorLight      - 环境光感参数
 *   FTMonitorInfoTypeSensorTorch      - 手电筒亮度
 *   FTMonitorInfoTypeFPS              - 每秒传输帧数
 */
typedef NS_OPTIONS(NSInteger, FTMonitorInfoType) {
    FTMonitorInfoTypeAll          = 1 << 0,
    FTMonitorInfoTypeBattery      = 1 << 1,
    FTMonitorInfoTypeMemory       = 1 << 2,
    FTMonitorInfoTypeCpu          = 1 << 3,
    FTMonitorInfoTypeGpu          = 1 << 4,
    FTMonitorInfoTypeNetwork      = 1 << 5,
    FTMonitorInfoTypeCamera       = 1 << 6,
    FTMonitorInfoTypeLocation     = 1 << 7,
    FTMonitorInfoTypeSystem       = 1 << 8,
    FTMonitorInfoTypeSensor       = 1 << 9,
    FTMonitorInfoTypeBluetooth    = 1 << 10,
    FTMonitorInfoTypeSensorBrightness   = 1 << 11,
    FTMonitorInfoTypeSensorStep         = 1 << 12,
    FTMonitorInfoTypeSensorProximity    = 1 << 13,
    FTMonitorInfoTypeSensorRotation     = 1 << 14,
    FTMonitorInfoTypeSensorAcceleration = 1 << 15,
    FTMonitorInfoTypeSensorMagnetic     = 1 << 16,
    FTMonitorInfoTypeSensorLight        = 1 << 17,
    FTMonitorInfoTypeSensorTorch        = 1 << 18,
    FTMonitorInfoTypeFPS                = 1 << 19,
};
      
 ```    	
  **注意：**    
  
   1. [关于GPU使用率获取](#2-关于-gpu-使用率)   
   2. [关于监控数据周期上报](#九监控数据周期上报)
    

  
### 6. 设置是否需要视图跳转流程图

 前提：设置全埋点 `enableAutoTrack =  YES;`。        
 设置 `enableScreenFlow = YES;` 时 ，将自动抓取视图跳转流程图。[具体流程图相关](#八流程图)。


## 四、参数与错误码
### 1. FTMobileConfig  可配置参数：

| 字段 | 类型 |说明|是否必须|
|:--------:|:--------:|:--------:|:--------:|
|  enableRequestSigning      |  BOOL      |配置是否需要进行请求签名  |是|
|metricsUrl|NSString|FT-GateWay metrics 写入地址|是|
|akId|NSString|access key ID| enableRequestSigning 为 true 时，必须要填|
|akSecret|NSString|access key Secret|enableRequestSigning 为 true 时，必须要填|
|enableLog|BOOL|设置是否允许打印日志|否（默认NO）|
|enableAutoTrack|BOOL|设置是否开启全埋点|否（默认NO）|
|autoTrackEventType|NS_OPTIONS|[全埋点抓取事件枚举](#4-设置是否开启全埋点)|否（默认FTAutoTrackTypeNone）|
|whiteViewClass|NSArray|UI控件白名单|否|
|blackViewClass|NSArray|UI控件黑名单|否|
|whiteVCList|NSArray|控制器白名单|否|
|blackVCList|NSArray|控制器黑名单|否|
|monitorInfoType|NS_OPTIONS|[采集数据](#5-采集数据配置)|否|
|needBindUser|BOOL|是否开启绑定用户数据|否(默认不开启)|
|enableScreenFlow|BOOL|设置是否需要视图跳转流程图|否（默认NO）|
|product|NSString|上报指标集名称|否|
|flushInterval|NSInteger|监控数据周期上报时间间隔|否（默认10s）|

### 2. 错误码

```objective-c
typedef enum FTError : NSInteger {
  NetWorkException = 101,            //网络问题
  InvalidParamsException = 102,      //参数问题
  FileIOException = 103,             //文件 IO 问题
  UnknownException = 104,            //未知问题
} FTError;

```

  
## 五、全埋点
  全埋点自动抓取的事件包括：项目启动、事件点击、页面浏览
### 1. Launch (App 启动) 
* 设置： `config.autoTrackEventType = FTAutoTrackEventTypeAppLaunch;`    
* 触发：  **App** 启动或从后台恢复时，触发 `launch `事件。    

### 2. Click  (事件点击)
* 设置： `config.autoTrackEventType = FTAutoTrackEventTypeAppClick;`    

* 触发： 控件被点击时，触发 **Click** 事件。    

* **Click** 事件中包含以下属性：    
    
      +  `root_page_name`：当前页面的根部页面
      +  `current_page_name`：当前页面
      +  `vtp`：操作页面树状路径

### 3. ViewScreen (页面enter、leave)
* 设置： `config.autoTrackEventType = FTAutoTrackEventTypeAppViewScreen;`    

* 触发：    
     +  当 `UIViewController` 的 `- viewDidAppear:` 被调用时，触发 **enter** 事件。
     +  当 `UIViewController` 的 `- viewDidDisappear:` 被调用时，触发 **leave** 事件。    

* **enter** 与 **leave** 事件中包含以下属性：
    
    +  `root_page_name`：当前页面的根部页面
    +  `current_page_name`：当前页面
    
### 4. 设置全埋点黑白名单
   黑白名单判断顺序： 白名单 -> 黑名单，控制器 -> UI控件    
   eg:    
   
1. 只有控制器 **A** 在 白名单 ，那么其余所有控制器无论是否在黑名单，全埋点事件都不抓取。
2. 控制器 **A** 在 黑名单 ，那么控制器 **A** 上所有全埋点事件都不抓取。
3. 只有 `UIButton`在 UI 控件白名单，那么其余 UI 控件的点击事件都不抓取。
4.  判断完 白名单 还会继续判断 黑名单 ，所以如果控制器 **A**  既在白名单又在黑名单，则控制器 **A** 全埋点事件都不抓取。

   + 控制器黑白名单设置     
   
   ```objective-c
     /**
        *  抓取界面（实例对象数组）  白名单 
        * eg: @[@"HomeViewController"];  字符串类型
     */
     @property (nonatomic,strong) NSArray *whiteVCList; 
		
     /**
        *  抓取界面（实例对象数组）  黑名单  
      */
     @property (nonatomic,strong) NSArray *blackVCList;
   ```
   + UI控件黑白名单设置
    
   ```objective-c
     /**
        * @abstract
        *  抓取某一类型的 View
        *  eg: @[UITableView.class];
     */
     @property (nonatomic,strong) NSArray<Class> *whiteViewClass;   
	 
     /**
        * @abstract
        *  忽略某一类型的 View
      */
     @property (nonatomic,strong) NSArray<Class> *blackViewClass;
   ```
	


## 六、主动埋点方法
 DF SDK 公开了 4 个埋点方法，用户通过这两个方法可以在需要的地方实现埋点，然后将数据上传到服务端。

### 1. 方法一：

```objective-c
  /**
追踪自定义事件。 存储数据库，等待上传
 @param measurement      指标（必填）
 @param field            指标值（必填）
*/ 
- (void)trackBackgroud:(NSString *)measurement field:(NSDictionary *)field;
```
 
### 2. 方法二：

```objective-c
/**
 追踪自定义事件。 存储数据库，等待上传
 
 @param measurement      指标（必填）
 @param tags             标签（选填）
 @param field            指标值（必填）
 */
- (void)trackBackgroud:(NSString *)measurement tags:(nullable NSDictionary*)tags field:(NSDictionary *)field;
```

### 3. 方法三：

```objective-c
/**
 追踪自定义事件。  立即上传 回调上传结果
 @param measurement      当前数据点所属的指标集
 @param field            自定义指标
*/
- (void)trackImmediate:(NSString *)measurement  field:(nullable NSDictionary *)field callBack:(void (^)(NSInteger statusCode,_Nullable id responseObject))callBackStatus;

```    

### 4. 方法四：

```objective-c
/**
追踪自定义事件。  立即上传 回调上传结果
@param measurement      当前数据点所属的指标集
@param tags             自定义标签
@param field            自定义指标
*/
- (void)trackImmediate:(NSString *)measurement tags:(nullable NSDictionary *)tags field:(NSDictionary *)field callBack:(void (^)(NSInteger statusCode,_Nullable id responseObject))callBackStatus;

```

### 5. 方法五：（批量上传）

```objective-c
/**
主动埋点，可多条上传。   立即上传 回调上传结果
@param trackList     主动埋点数据数组
*/
- (void)trackImmediateList:(NSArray <FTTrackBean *>*)trackList callBack:(void (^)(NSInteger statusCode, _Nullable id responseObject))callBackStatus;

```
**FTTrackBean** 的属性：

```objective-c
//当前数据点所属的指标集 (必须)
@property (nonatomic, strong) NSString *measurement;
//自定义标签 （可选）
@property (nonatomic, strong) NSDictionary *tags;
//自定义指标 (必须)
@property (nonatomic, strong) NSDictionary *field;
//需要为毫秒级13位时间戳 (可选)
@property (nonatomic, assign) long long  timeMillis;

```


### 6. 方法使用示例

```objective-c
 //等待上传
[[FTMobileAgent sharedInstance] trackBackgroud:@"home.operation" tags:@{@"pushVC":@"SecondViewController"} field:@{@"event":@"BtnClick"}];
   
```    

```objective-c
 //立即上传
[[FTMobileAgent sharedInstance] trackImmediate:@"home.operation" tags:@{@"pushVC":@"SecondViewController"} field:@{@"event":@"BtnClick"}];
   
```


## 七、用户的绑定与注销 
 FT SDK 提供了绑定用户和注销用户的方法，`FTMobileConfig` 属性 `needBindUser = YES ;`（默认为 `NO`）时，用户登录绑定后，才会进行数据的传输。   
 
### 1. 用户绑定：
 
```objective-c
  /**
绑定用户信息
 @param name     用户名
 @param Id       用户Id
 @param exts     用户其他信息
*/
- (void)bindUserWithName:(NSString *)name Id:(NSString *)Id exts:(nullable NSDictionary *)exts;
```

### 2. 用户注销：

```objective-c
/**
 注销当前用户
*/
- (void)logout;
```

### 3. 方法使用示例

```objective-c
//登录后 绑定用户信息
    [[FTMobileAgent sharedInstance] bindUserWithName:userName Id:userId exts:nil];
```

```objective-c
//登出后 注销当前用户
    [[FTMobileAgent sharedInstance] logout];
```

## 八、流程图
### 1. 全埋点上报流程图
抓取 App 一个生命周期内的页面 **Open** 事件，可绘制出用户使用 App 时的页面跳转流程图，并显示出在页面的停留时间。
 设置方法：    
 
```objective-c
 FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:@"Your App metricsUrl" akId:@"Your App akId" akSecret: @"Your App akSecret" enableRequestSigning:YES];
 [config enableTrackScreenFlow:YES];//设置开启全埋点上报流程图
```
### 2. 主动埋点上报流程图
 DF SDK 公开了 2 个方法，用户通过这两个方法可以在需要的地方实现流程图埋点，然后将数据上传到服务端。
 
1. 方法一

 ```objective-c
 /**
 上报流程图
 @param product   指标集 命名只能包含英文字母、数字、中划线和下划线，最长 40 个字符，区分大小写
 @param traceId   标示一个流程单的唯一 ID
 @param name      流程节点名称
 @param parent    当前流程节点的上一个流程节点的名称，如果是流程的第一个节点，可不上报
 @param duration  流程单在当前流程节点滞留时间或持续时间，毫秒为单位
*/
- (void)flowTrack:(NSString *)product traceId:(NSString *)traceId name:(NSString *)name parent:(nullable NSString *)parent duration:(long)duration;

 ```

2. 方法二

 ```objective-c
/**
 上报流程图
 @param product   指标集 命名只能包含英文字母、数字、中划线和下划线，最长 40 个字符，区分大小写
 @param traceId   标示一个流程单的唯一 ID
 @param name      流程节点名称
 @param parent    当前流程节点的上一个流程节点的名称，如果是流程的第一个节点，可不上报
 @param tags      自定义标签
 @param duration  流程单在当前流程节点滞留时间或持续时间，毫秒为单位
 @param values    自定义指标
*/
- (void)flowTrack:(NSString *)product traceId:(NSString *)traceId name:(NSString *)name parent:(nullable NSString *)parent tags:(nullable NSDictionary *)tags duration:(long)duration values:(nullable NSDictionary *)values;

 ```

3. 使用示例


 ```objective-c
 //节点一：
 [[FTMobileAgent sharedInstance] flowTrack:@"oa" traceId:@"fid_1" name:@"提交申请" parent:nil tags:@{@"申请人":@"张三"} duration:0];
 
 //节点二：
 [[FTMobileAgent sharedInstance] flowTrack:@"oa" traceId:@"fid_1" name:@"直属领导审批" parent:@"提交申请" tags:@{@"申请人":@"张三",@"审批人":@"李四"} duration:1800000];

 ```    
 
## 九、监控数据周期上报 
### 1.监控周期设置 
  在 `FTMobileConfig` 中设置 `flushInterval `。
  
 1.  方法 
       
 ```objective-c 
//FTMobileConfig  
 /**
  * @property
  *
  * @abstract
  * 两次数据发送的时间间隔，单位秒
  *
  * @discussion
  * 默认值为 10 秒
 */
@property (nonatomic) NSInteger flushInterval;   
 ``` 
   
 ```objective-c  
// FTMobileAgent  
/**
 * 设置 监控上传周期
 */
-(void)setMonitorFlushInterval:(NSInteger)interval;
 ```    
 2. 使用示例：
   
 ```objective-c   
  //FTMobileConfig  
  
  config.flushInterval = 15;
 ``` 
 
 ```objective-c   
 //FTMobileAgent
 
 [[FTMobileAgent sharedInstance] setMonitorFlushInterval:10];

 ``` 

###  2. 启动上传    
 1.  方法    

 ```objective-c    
/**
 * 开启监控同步
 */
-(void)startMonitorFlush;
 ```     
       
 
 2. 使用示例：
 
 ```objective-c   
  [[FTMobileAgent sharedInstance] startMonitorFlush];
  
 ```      
 
### 3.有关监控项注意事项    
 * 权限使用    
    
| 监控类型| 使用权限 |
|:--------:|:--------:|
|  FTMonitorInfoTypeLocation  |Privacy - Location Always Usage Description、Privacy - Location When In Use Usage Description、Privacy - Location Usage Description （按需求选择一个或读多个）|
| FTMonitorInfoTypeSensor、FTMonitorInfoTypeSensorStep、FTMonitorInfoTypeSensorProximity、FTMonitorInfoTypeSensorRotation、FTMonitorInfoTypeSensorAcceleration、FTMonitorInfoTypeSensorMagnetic   |  Privacy - Motion Usage Description|
|FTMonitorInfoTypeSensorLight|Privacy - Camera Usage Description|
|FTMonitorInfoTypeBluetooth|Privacy - Bluetooth Always Usage Description|

 * 当 `FTMonitorInfoType` 设置为 `FTMonitorInfoTypeAll` 全部监控项抓取。
 * 当 `FTMonitorInfoType` 中的 `FTMonitorInfoTypeSensor` 包含（`FTMonitorInfoTypeSensorStep`   、`FTMonitorInfoTypeSensorProximity`   、`FTMonitorInfoTypeSensorRotation`、`FTMonitorInfoTypeSensorAcceleration`   、`FTMonitorInfoTypeSensorMagnetic` 、`FTMonitorInfoTypeSensorLight`、`FTMonitorInfoTypeSensorTorch` ）设置这一项会一并抓取，无须另外设置。 如果只抓取传感器的某一项，单独设置需要的即可。
 *  `FTMonitorInfoTypeSensorLight`   利用摄像头获取环境光感参数, 启动`AVCaptureSession `，获取视频流数据后可以分析得到当前的环境光强度。
 *  `FTMonitorInfoTypeSensorTorch`  获取应用内设置的手电筒亮度级别。
 *   `FTMonitorInfoTypeBluetooth` 获取应用已匹配过的外设信息，需要开发者在第一次匹配时,保存起来,比如用 **NSUserDefaults**。  
  使用以下方法将信息传给 SDK 。 
 
 ```objective-c
 /**
 * 在监控项设置抓取蓝牙后使用
 * 设置设备连接过的蓝牙外设 CBUUID 数组，建议用户将已连接过的设备使用NSUserDefault保存起来
 * 用于采集已连接设备相关信息
*/
-(void)setConnectBluetoothCBUUID:(nullable NSArray<CBUUID *> *)serviceUUIDs;
```  
使用示例:

 ```objective-c
 [[FTMobileAgent sharedInstance] setConnectBluetoothCBUUID:@[[CBUUID UUIDWithString:serviceUUID0],[CBUUID UUIDWithString:characteristicUUID4],[CBUUID UUIDWithString:characteristicHeartUUID0]]];
 
 ```     
 
## 十、常见问题
### 1. 关于查询指标 IMEI
   因为隐私问题，苹果用户在 iOS5 以后禁用代码直接获取 **IMEI** 的值。所以 iOS SDK 中不支持获取 **IMEI**。
   
### 2. 关于 GPU 使用率
 获取 **GPU 使用率** ，需要使用到 `IOKit.framework ` 私有库，**可能会影响 AppStore 上架**。如果需要此功能，需要在你的应用安装 `IOKit.framework ` 私有库。导入后，请在编译时加入 `FT_TRACK_GPUUSAGE` 标志，SDK 将会为你获取 **GPU 使用率**。    
     
  XCode 设置方法 :      
  
  ```objective-c
Build Settings > Apple LLVM 7.0 - Preprocessing > Processor Macros >
Release : FT_TRACK_GPUUSAGE=1
  ```
