
# Dataflux-SDK-iOS
[Dataflux-SDK-iOS-Demo](https://github.com/CloudCare/dataflux-sdk-ios-demo)   

**FTMobileSDK**

![Cocoapods platforms](https://img.shields.io/cocoapods/p/FTMobileAgent)
![Cocoapods](https://img.shields.io/cocoapods/v/FTMobileSDK)
![Cocoapods](https://img.shields.io/cocoapods/l/FTMobileSDK)

## 一、 导入SDK
   你可以使用下面方法进行导入：
### 1. 直接下载下来安装
1. 从 [GitHub](https://github.com/CloudCare/dataflux-sdk-ios) 获取 SDK 的源代码。	 
2. 将 SDK 源代码导入 App 项目，并选中 `Copy items if needed`。    
      -  需要全埋点功能：直接将 **FTMobileSDK** 整个文件夹导入项目。
      -  不需要全埋点功能：只导入 **FTMobileAgent** 即可。
3. 添加依赖库：项目设置 `Build Phase` -> `Link Binary With Libraries` 添加：`UIKit` 、 `Foundation` 、`libz.tbd`，如果监控项开启且抓取网络数据，则需要添加 `libresolv.9.tbd`。


### 2. 通过 CocoaPods 导入

1. 配置 `Podfile` 文件。    
    
  ```objective-c
  target 'yourProjectName' do

  # Pods for your project
  //如果需要全埋点功能
   pod 'FTMobileSDK'    
    
  //不需要全埋点功能
   pod 'FTMobileSDK/FTMobileAgent'
    
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
 	
### 2.设置日志相关    
- enableLog 打印日志    

   在 **debug** 环境下，设置 `FTMobileConfig` 的 `enableLog` 属性。
   
   ```objective-c
    config.enableLog = YES; //打印日志
   ```

- enableDescLog 打印描述日志   

   在 **debug** 环境下，设置 `FTMobileConfig` 的 `enableDescLog` 属性。辅助设置 **page_desc** 与 **vtp_desc** ,将打印 `vtp`、`current_page_name`、`vtp_desc`、`page_desc` 。   
   

   ```objective-c
   config.enableDescLog = YES; //打印描述日志
    
   //打印显示
   [FTLog][DESCINFO]  -[FTAutoTrack track:withCpn:WithClickView:index:] [line 381]  vtp : UITestVC/UIWindow/UITransitionView/UIDropShadowView/UILayoutContainerView/UITransitionView/UIViewControllerWrapperView/UILayoutContainerView/UINavigationTransitionView/UIViewControllerWrapperView/UIView/UIScrollView/UIButton[1]
   [FTLog][DESCINFO]  -[FTAutoTrack track:withCpn:WithClickView:index:] [line 374]  page_desc : 首页    
    
   ```    
   
- enableTrackAppCrash 采集崩溃日志

   ```objective-c 
  /**
   *设置是否需要采集崩溃日志 默认为NO
   */
@property (nonatomic, assign) BOOL enableTrackAppCrash;
  
   ```    
     
  [崩溃分析](#3-关于崩溃日志分析)    
      
 
- traceConsoleLog 采集控制台日志    

   一般情况下， 因为 NSLog 的输出会消耗系统资源，而且输出的数据也可能会暴露出App里的保密数据， 所以在发布正式版时会把这些输出全部屏蔽掉。此时开启采集控制台日志，也并不能抓取到工程里打印的日志。建议使用 [日志写入接口](#2上报日志) 来上传想查看的日志。
 
   ```objective-c 
  /**
   *设置是否需要采集控制台日志 默认为NO
   */
@property (nonatomic, assign) BOOL traceConsoleLog;

   ```    
    
- eventFlowLog 采集页面事件日志
    
  设置后，可以在 web 版本日志中，查看到对应上报的日志，事件支持启动应用，进入页面，离开页面，事件点击等。  
     
 ```objective-c
 /**
 * 默认为NO
 * 需 AutoTrack 开启 ，设置对应采集类型时生效
 */
 @property (nonatomic, assign) BOOL eventFlowLog; 
 ```

 
     
### 3. 设置X-Datakit-UUID
 `X-Datakit-UUID` 是 SDK 初始化生成的 UUID, 应用清理缓存后(包括应用删除)，会重新生成。
 `FTMobileConfig` 配置中，开发者可以强制更改。更改方法：

 ```objective-c
   [config setXDataKitUUID:@"YOUR UUID"];
 ```

### 4. 设置是否开启全埋点  

   开启全埋点，设置 `FTMobileConfig` 的 `enableAutoTrack = YES ;` 。
   在 `enableAutoTrack = YES;` 的情况下，进行 `autoTrackEventType` 类型设置。    

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

### 6.设置是否开启页面、视图树描述  
 
  ``` objective-c
 /**
 * 是否开启页面、视图树 描述 默认 NO
 */
 @property (nonatomic, assign) BOOL enabledPageVtpDesc;@property (nonatomic, assign) float collectRate;
  ```      
  
  [设置页面描述、视图树描述配置方法](#九设置页面描述视图树描述配置)    
  
### 7.设置网络追踪
-  开启网络请求信息采集
  
 ``` objective-c   
/**
 * 设置网络请求信息采集 默认为NO
 */
@property (nonatomic, assign) BOOL networkTrace;

 ```    
    
- 设置采集率
 
  ``` objective-c
  /**
   *  设置网络请求信息采集时 采样率 0-1 默认为 1
   */
  @property (nonatomic, assign) float traceSamplingRate;
  ```    
   
      
-  设置网络请求信息采集时 使用链路追踪类型 
   
 ``` objective-c   
/**
 *  设置网络请求信息采集时 使用链路追踪类型 type 默认为 Zipkin 
 *  FTNetworkTrackTypeZipkin 、FTNetworkTrackTypeJaeger 、FTNetworkTrackTypeSKYWALKING_V3
 */
@property (nonatomic, assign) FTNetworkTrackType networkTraceType;
/**
 *  开启网络请求信息采集 并设置链路追踪类型 type 默认为 Zipkin
 *  @param  type   链路追踪类型 默认为 Zipkin
 */
-(void)networkTraceWithTraceType:(FTNetworkTrackType)type;

 ```    
  
-  设置网络请求采集 Content-Type 类型     
   
  采集的 **__content** 大小限制在 30k 。 
  
  ``` objective-c   
 /**
 *  设置 网络请求采集 支持的 contentType
 *  默认采集  Content-Type（application/json、application/xml、application/javascript、text/html、text/xml、text/plain、application/x-www-form-urlencoded、multipart/form-data）
*/
@property (nonatomic, strong) NSArray <NSString *> *networkContentType;
  ```
   
## 四、参数与错误码
### 1. FTMobileConfig  可配置参数：

|          字段          |     类型     |            说明             |                是否必须                |
| :------------------: | :--------: | :-----------------------: | :--------------------------------: |
| enableRequestSigning |    BOOL    |       配置是否需要进行请求签名        |                 是                  |
|      metricsUrl      |  NSString  |  FT-GateWay metrics 写入地址  |                 是                  |
|         akId         |  NSString  |       access key ID       | enableRequestSigning 为 true 时，必须要填 |
|       akSecret       |  NSString  |     access key Secret     | enableRequestSigning 为 true 时，必须要填 |
|      enableLog       |    BOOL    |        设置是否允许打印日志         |              否（默认NO）               |
|    enableDescLog     |    BOOL    |       设置是否允许打印描述日志        |              否（默认NO）               |
|   enableAutoTrack    |    BOOL    |         设置是否开启全埋点         |              否（默认NO）               |
|  autoTrackEventType  | NS_OPTIONS | [全埋点抓取事件枚举](#4-设置是否开启全埋点) |      否（默认FTAutoTrackTypeNone）      |
|    whiteViewClass    |  NSArray   |          UI控件白名单          |                 否                  |
|    blackViewClass    |  NSArray   |          UI控件黑名单          |                 否                  |
|     whiteVCList      |  NSArray   |          控制器白名单           |                 否                  |
|     blackVCList      |  NSArray   |          控制器黑名单           |                 否                  |
|   monitorInfoType    | NS_OPTIONS |     [采集数据](#5-采集数据配置)     |                 否                  |
|     needBindUser     |    BOOL    |        是否开启绑定用户数据         |              否(默认不开启)              |
|    flushInterval     | NSInteger  |       监控数据周期上报时间间隔        |              否（默认10s）              |
|   enableTrackAppCrash   |    BOOL    |       设置是否需要采集崩溃日志      |              否（默认NO）              |
|   traceServiceName   |    NSString    |       设置日志所属业务或服务的名称      |              否（默认dataflux sdk）              |
|   traceConsoleLog   |    BOOL    |       设置是否需要采集控制台日志      |              否（默认NO）              |
|   eventFlowLog   |    BOOL    |       设置是否采集页面事件日志  |              否（默认NO）              |
|   networkTrace   |    BOOL    |       设置网络请求信息采集  |              否（默认NO）              |
| traceSamplingRate |float|设置网络请求信息采集率|否（默认1）|
|   networkTraceType   |    FTNetworkTrackType    |   设置网络请求信息采集时 使用链路追踪类型 | 否（默认Zipkin）         |
|networkContentType|NSArray|设置 网络请求采集 支持的 contentType|否（默认采集  Content-Type（application/json、application/xml、application/javascript、text/html、text/xml、text/plain、application/x-www-form-urlencoded、multipart/form-data））|


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
  全埋点自动抓取的事件包括：项目启动、事件点击、页面浏览 。 全埋点数据会先存储在数据库中，等待时机上传。
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


## 六、主动上报方法
 DF SDK 公开了 2 类上报方法， 2 种上传机制。   
 
 *  上报方法    
  1. 上报主动埋点
  2. 上报日志

  
*  上传机制     
 **background** 上传机制 : 将数据存储到数据库中，等待时机进行上传。数据库存储量限制在 5000 条，如果网络异常等原因导致数据堆积，存储 5000 条后，会丢弃新传入的数据。    
 **immediate** 上传机制 : 立即上传，回调上传结果。


### 1.上报主动埋点
* background方法    

```objective-c

 /**
 追踪自定义事件。 存储数据库，等待上传
 
 @param measurement      指标（必填）
 @param tags             标签（选填）
 @param field            指标值（必填）
 */
- (void)trackBackgroud:(NSString *)measurement field:(NSDictionary *)field; 

- (void)trackBackgroud:(NSString *)measurement tags:(nullable NSDictionary*)tags field:(NSDictionary *)field;
```

* immediate 方法    

```objective-c
/**
追踪自定义事件。  立即上传 回调上传结果
@param measurement      当前数据点所属的指标集
@param tags             自定义标签
@param field            自定义指标
*/
- (void)trackImmediate:(NSString *)measurement  field:(nullable NSDictionary *)field callBack:(void (^)(NSInteger statusCode,_Nullable id responseObject))callBackStatus;

- (void)trackImmediate:(NSString *)measurement tags:(nullable NSDictionary *)tags field:(NSDictionary *)field callBack:(void (^)(NSInteger statusCode,_Nullable id responseObject))callBackStatus;

/**
主动埋点，可多条上传。   立即上传 回调上传结果
@param trackList     主动埋点数据数组
*/
- (void)trackImmediateList:(NSArray <FTTrackBean *>*)trackList callBack:(void (^)(NSInteger statusCode, _Nullable id responseObject))callBackStatus;
```


* **FTTrackBean** 的属性：
 

| 属性名 | 类型 |必需|说明|
|--------|--------|--------|--------|
|    measurement    |   NSString     |   是     |  当前数据点所属的指标集      |
|    tags    |  NSDictionary      |     否  |   自定义标签     |
|    field    | NSDictionary       |   是    |  自定义指标      |
|    timeMillis    | long long       |   否    |  需要为毫秒级13位时间戳      |


* 方法使用示例

```objective-c
 //等待上传
[[FTMobileAgent sharedInstance] trackBackgroud:@"home.operation" tags:@{@"pushVC":@"SecondViewController"} field:@{@"event":@"BtnClick"}];
   
```

```objective-c
 //立即上传
[[FTMobileAgent sharedInstance] trackImmediate:@"home.operation" tags:@{@"pushVC":@"SecondViewController"} field:@{@"event":@"BtnClick"}];
   
```

### 2.上报日志
* background 方法 

```objective-c
typedef NS_ENUM(NSInteger, FTStatus) {
    FTStatusInfo         = 0,
    FTStatusWarning,
    FTStatusError,
    FTStatusCritical,
    FTStatusOk,
};
/**
 * 日志上报
 * @param content  日志内容，可为json字符串
 * @param status   事件等级和状态，info：提示，warning：警告，error：错误，critical：严重，ok：恢复，默认：info

 */
-(void)logging:(NSString *)content status:(FTStatus)status;
``` 

    
 * 方法使用示例
 
```objective-c
    [[FTMobileAgent sharedInstance] logging:@"TestLoggingBackground" status:FTStatusInfo];

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

## 八、监控数据周期上报 
### 1.监控周期设置 
  在 `FTMobileConfig` 中设置 `flushInterval `。

* 方法     
    
 ```objective-c   
 // FTMobileAgent  
 /**
 * 设置 监控上传周期 默认为 10 秒
 */
-(void)setMonitorFlushInterval:(NSInteger)interval;
 ```
    
* 使用示例：


 ```objective-c   
 //FTMobileAgent
 
 [[FTMobileAgent sharedInstance] setMonitorFlushInterval:10];

 ```

###  2. 启动上传    
* 方法    

 ```objective-c    
/**
 * 开启监控同步
 */
-(void)startMonitorFlush;
 ```

 ```objective-c    
/**
 * 开启监控同步，并设置上传时间间隔，监控类型
 * @param interval    上传周期
 * @param type        监控类型 设置后会更改config中 monitorType的设置
*/
-(void)startMonitorFlushWithInterval:(NSInteger)interval monitorType:(FTMonitorInfoType)type;
 ```
  
* 使用示例：

 ```objective-c   
  [[FTMobileAgent sharedInstance] startMonitorFlush];
  
 ```

  ```objective-c   
  [[FTMobileAgent sharedInstance] startMonitorFlushWithInterval:10 monitorType:FTMonitorInfoTypeAll];
  
  ```

### 3.关闭上传 
* 方法    

 ```objective-c    
/**
 * 关闭监控同步
 */
-(void)stopMonitorFlush;
 ```


* 使用示例：

 ```objective-c   
  [[FTMobileAgent sharedInstance] stopMonitorFlush];
  
 ```

### 4.有关监控项注意事项    
#### 1.权限使用    

|                   监控类型                   |                   使用权限                   |
| :--------------------------------------: | :--------------------------------------: |
| FTMonitorInfoTypeLocation、FTMonitorInfoTypeNetwork | Privacy - Location Always Usage Description、Privacy - Location When In Use Usage Description、Privacy - Location Usage Description （按需求选择一个或多个） |
| FTMonitorInfoTypeSensor、FTMonitorInfoTypeSensorStep、FTMonitorInfoTypeSensorProximity、FTMonitorInfoTypeSensorRotation、FTMonitorInfoTypeSensorAcceleration、FTMonitorInfoTypeSensorMagnetic |    Privacy - Motion Usage Description    |
|       FTMonitorInfoTypeSensorLight       |    Privacy - Camera Usage Description    |
|        FTMonitorInfoTypeBluetooth        | Privacy - Bluetooth Always Usage Description |
#### 2.FTMonitorInfoTypeAll

  当 `FTMonitorInfoType` 设置为 `FTMonitorInfoTypeAll` 时，全部监控项会被抓取。   


#### 3. FTMonitorInfoTypeSensor
|     FTMonitorInfoTypeSensor 包含      |       注释        |
| :---------------------------------: | :-------------: |
|     FTMonitorInfoTypeSensorStep     |      当天步数       |
|  FTMonitorInfoTypeSensorProximity   |      距离传感器      |
|   FTMonitorInfoTypeSensorRotation   |   陀螺仪三轴旋转角速度    |
| FTMonitorInfoTypeSensorAcceleration |     三轴线性加速度     |
|   FTMonitorInfoTypeSensorMagnetic   |     三轴地磁强度      |
|    FTMonitorInfoTypeSensorLight     |     环境光感参数      |
|    FTMonitorInfoTypeSensorTorch     | 获取应用内设置的手电筒亮度级别 |

 - 设置 `FTMonitorInfoTypeSensor` 会一并抓取传感器数据，无须另外设置。 如果只抓取传感器的某一项，单独设置需要的即可。   

 - `FTMonitorInfoTypeSensorLight`：[谨慎开启环境光感参数监控项](#3-谨慎开启环境光感参数监控项) SDK 是利用摄像头获取环境光感参数, 启动`AVCaptureSession `，获取视频流数据后可以分析得到当前的环境光强度，**iOS14 中 App 使用相机时会有图标以及绿点提示，并且会显示当前是哪个 App 在使用此功能，我们无法控制是否显示该提示** 所以建议谨慎开启此项。

 
 - `FTMonitorInfoTypeSensorProximity` ：会开启距离传感器。当有物体靠近听筒时,屏幕会自动变暗。

#### 4. FTMonitorInfoTypeNetwork 
   **iOS 12** 之后 获取 **WifiSSID** 需要配置 `'capability' ->'Access WiFi Infomation'` 才能获取， **iOS 13** 之后需要开启定位权限，才能获取到信息。

#### 5. FTMonitorInfoTypeBluetooth 

  `FTMonitorInfoTypeBluetooth` 获取应用已匹配过的外设信息，需要开发者在第一次匹配时,保存起来,比如用 **NSUserDefaults**。  
  使用以下方法将信息传给 SDK 。 

```objective-c
 /**
 * 在监控项设置抓取蓝牙后使用
 * 设置设备连接过的蓝牙外设 CBUUID 数组，建议用户将已连接过设备的identifier使用NSUserDefault保存起来  
 * 用于采集已连接设备相关信息
*/
-(void)setConnectBluetoothCBUUID:(nullable NSArray<CBUUID *> *)serviceUUIDs;
```
使用示例:

```objective-c

 [[FTMobileAgent sharedInstance] setConnectBluetoothCBUUID:@[[CBUUID UUIDWithString:@"蓝牙设备identifier"]];
 
```

## 九、设置页面描述、视图树描述配置
### 1. 设置是否允许描述
*  FTMobileConfig `enabledPageVtpDesc` 属性设置    

  ```objective-c
   /**
  * 是否开启页面、视图树 描述 默认 NO
  */
  @property (nonatomic, assign) BOOL enabledPageVtpDesc;
  ```

### 2. 添加页面描述、视图树描述 XML 文件
创建以 `ft_page_vtp_desc` 为名的 **xml** 文件，按照下面格式添加**页面描述**、**视图树描述**。将 `ft_page_vtp_desc.xml` 文件添加到项目工程中。

* 格式示例   

 ```xml
<root>
<pagedesc>
<page name="RootTabbarVC" desc="底部导航" />
<page name="DemoViewController" desc="首页" />
</pagedesc>
<vtpdesc>
<vtp path="UITabBarController/UIWindow/UITransitionView/UIDropShadowView/UILayoutContainerView/UITabBar/UITabBarButton[1]" desc="home点击" />
</vtpdesc>
</root>
  
 ```


### 3. vtp 的获取

  -  一般UI控件的 **vtp** 获取    

     [开启描述日志的开关](#2设置日志)。运行程序，打开你需要设置描述的页面，点击你需要设置描述的按钮等控件，然后找到控制台输出的对应日志。    

  -   关于 **UITableView** 、**UICollectionView**  的 **vtp**    

      **UITableView** 、**UICollectionView** 可以设置 **vtp** 中是否添加 **NSIndexPath** 的 **row**、**section**

  - 设置方法：    
     

    ``` objective-c      
    #import <FTMobileAgent.h>
           
    mtableView.vtpAddIndexPath = YES;
       
    ```

  - vtp显示：    

    ``` objective-c      
    // 不添加 NSIndexPath
    vtp: UIWindow/UITransitionView/UIDropShadowView/UILayoutContainerView/UITransitionView/UIViewControllerWrapperView/UILayoutContainerView/UINavigationTransitionView/UIViewControllerWrapperView/UIView/UITableView[0]
    //添加 NSIndexPath
    vtp: UIWindow/UITransitionView/UIDropShadowView/UILayoutContainerView/UITransitionView/UIViewControllerWrapperView/UILayoutContainerView/UINavigationTransitionView/UIViewControllerWrapperView/UIView/UITableView[0]/section[0]/row[0]    
    ```   


## 十、常见问题
### 1. 关于查询指标 IMEI
   因为隐私问题，苹果用户在 iOS5 以后禁用代码直接获取 **IMEI** 的值。所以 iOS SDK 中不支持获取 **IMEI**。

### 2. 关于 GPU 使用率
 获取 **GPU 使用率** ，需要使用到 `IOKit.framework ` 私有库，**可能会影响 AppStore 上架**。如果需要此功能，需要在你的应用安装 `IOKit.framework ` 私有库。导入后，请在编译时加入 `FT_TRACK_GPUUSAGE` 标志，SDK 将会为你获取 **GPU 使用率**。    
​     
  XCode podfile 设置方法 :      

  ```objective-c
 pod 'FTMobileSDK' 
 post_install do |installer_representation|
           installer_representation.pods_project.targets.each do |target|
               if target.name == 'FTMobileSDK'
                   target.build_configurations.each do |config|
                           config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= ['$(inherited)','FT_TRACK_GPUUSAGE=1']
                           puts "===================>target build configure #{config.build_settings}"
                   end
               end
           end
       end
  ```

### 3. 关于崩溃日志分析
在开发时的 **Debug** 和 **Release** 模式下，**Crash** 时捕获的线程回溯是被符号化的。
而发布包没带符号表，异常线程的关键回溯，会显示镜像的名字，不会转化为有效的代码符号，获取到的 **crash log** 中的相关信息都是 16 进制的内存地址，并不能定位崩溃的代码，所以需要将 16 进制的内存地址解析为对应的类及方法。

#### 利用命令行工具解析 **Crash**     
需要的文件：    

1. 需要从 **DataFlux** 下载 **SDK** 采集上传的崩溃日志。下载后将后缀改为 **.crash**。
2. 需要 **App** 打包时产生的 **dSYM** 文件，必须使用当前应用打包的电脑所生成的 **dSYM** 文件，其他电脑生成的文件可能会导致分析不准确的问题，因此每次发包后建议根据应用的**版本号**或 **dSYM** 文件的 **UUID** 来对应保存**dSYM** 文件。以备解析时，根据后台日志 tag 中的版本名字段（app_version_name）或 崩溃日志中的 **dSYMUUID** 对应的 **UUID** 来找到对应**dSYM**文件。
3. 需要使用 **symbolicatecrash**，**Xcode**自带的崩溃分析工具，使用这个工具可以更精确的定位崩溃所在的位置，将0x开头的地址替换为响应的代码和具体行数。 
   
    > 查找 **symbolicatecrash**方法  
    终端输入 
    `find /Applications/Xcode.app -name symbolicatecrash -type f`    
    
    >/Applications/Xcode.app/Contents/SharedFrameworks/DVTFoundation.framework/Versions/A/Resources/symbolicatecrash

进行解析：    

 1. 将 **symbolicatecrash** 与 **.crash** 和 **.app.dSYM** 放在同一文件夹中    
  
 2. 开启命令行工具，进入文件夹   
  
 3. 使用命令解析 **Crash** 文件，*号指的是具体的文件名    
      
    ```
    ./symbolicatecrash ./*.crash ./*.app.dSYM > symbol.crash
    ```   
   
 4. 解析完成后会生成一个新的 **.Crash** 文件，这个文件中就是崩溃详细信息。


### 4. 谨慎开启环境光感参数监控项
     
   iOS14 中 App 使用相机会有图标以及绿点提示，并且会显示当前是哪个 App 在使用此功能，并且我们无法控制是否显示该提示。    
  
  触发相机小绿点的代码示例:    
  
```   
AVCaptureDeviceInput *videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:videoCaptureDevice error:nil];
AVCaptureSession *session = [[AVCaptureSession alloc] init];
if ([session canAddInput:videoInput]) {
    [session addInput:videoInput];
}
[session startRunning];
```
   在 SDK 中获取环境光感参数的方法是, 启动 AVCaptureSession ，获取视频流数据，分析得到当前的环境光强度，使用了上面的接口 ，所以会**触发相机小绿点**。
   
   
 





