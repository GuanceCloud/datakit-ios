
# Dataflux-SDK-iOS
[Dataflux-SDK-iOS-Demo](https://github.com/CloudCare/dataflux-sdk-ios-demo)   

**FTMobileSDK**

![Cocoapods platforms](https://img.shields.io/cocoapods/p/FTMobileAgent)
![Cocoapods](https://img.shields.io/cocoapods/v/FTMobileSDK)
![Cocoapods](https://img.shields.io/cocoapods/l/FTMobileSDK)

## 一、 导入SDK
   你可以使用下面方法进行导入：
### 1. 直接下载下来安装
1. 从 [GitHub]() 获取 SDK 的源代码。	 
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
 	
### 2.设置日志    
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

### 7. 设置采集率
 
  ``` objective-c
  /**
 * 设置采样率 0-1 默认为 1
 */
@property (nonatomic, assign) float collectRate;
  ```
  
### 8. 是否需要采集崩溃日志
  ```objective-c 
  /**
   *设置是否需要采集崩溃日志 默认为NO
   */
@property (nonatomic, assign) BOOL enableTrackAppCrash;

 /**
   * 崩溃日志所属环境，比如可用 dev 表示开发环境，prod 表示生产环境，用户可自定义
   */
@property (nonatomic, copy) NSString *loggingEnv;
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
|   enableScreenFlow   |    BOOL    |       设置是否需要视图跳转流程图       |              否（默认NO）               |
|    flushInterval     | NSInteger  |       监控数据周期上报时间间隔        |              否（默认10s）              |

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


## 六、主动上报方法
 DF SDK 公开了 4 类上报方法 。    
 
1.  上报主动埋点
2. 上报日志
3. 上报对象数据
4. 上报事件数据 

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
* background方法 

```objective-c
-(void)loggingBackground:(FTLoggingBean *)logging;
``` 

* immediate 方法   

```objective-c
//单条
-(void)loggingImmediate:(FTLoggingBean *)logging callBack:(nullable void (^)(NSInteger statusCode, _Nullable id responseObject))callBackStatus;
//多条
-(void)loggingImmediateList:(NSArray <FTLoggingBean *> *)loggingList callBack:(nullable void (^)(NSInteger statusCode, _Nullable id responseObject))callBackStatus;

```   

*  **FTLoggingBean** 的属性    

| 属性名 | 类型 |必需|说明|
|--------|--------|--------|--------|
|    measurement    |   NSString     |   是     |  指定当前日志的来源，比如如果来源于 Ngnix，可指定为 Nginx，同一应用产生的日志 应该一样      |
|    content    |  NSString      |     是  |   日志内容，纯文本或 JSONString 都可以      |
|    source    | NSString       |   否    |  日志来源，日志上报后，会自动将指定的指标集名作为该标签附加到该条日志上      |
|    serviceName    |  NSString      |   否    |  日志所属业务或服务的名称，建议用户通过该标签指定产生该日志业务系统的名称     |
|    env    |  NSString      |   否    |  日志所属环境，比如可用 dev 表示开发环境，prod 表示生产环境，用户可自定义    |
|    serviceName    |  NSString      |   否    |  日志所属业务或服务的名称，建议用户通过该标签指定产生该日志业务系统的名称     |
|    status    |  FTStatus      |   否    |  日志等级，状态，info：提示，warning：警告，error：错误，critical：严重，ok：成功，默认：info     |
|    parentID    |  NSString      |   否    |  用于链路日志，表示当前 span 的上一个 span的 ID   |
|    operationName    |  NSString      |   否    |  用于链路日志，表示当前 span 操作名，也可理解为 span 名称    |
|    spanID    |  NSString      |   否    |  用于链路日志，表示当前 span 的 ID    |
|    traceID    |  NSString      |   否    |  用于链路日志，表示当前链路的 ID    |
|    errorCode    |  int      |   否    |  用于链路日志，请求的响应代码，例如 200 表示请求成功     |
|    tags    |  NSDictionary      |   否    |  自定义标签   |
|    field    |  NSDictionary      |   否    |  自定义指标  （可选）   |
|    deviceUUID    |  NSString      |   否    |  设备UUID    |
|    duration    |  int      |   否    |  用于链路日志，当前链路的请求响应时间，微秒为单位|
    
 * 方法使用示例
 
```objective-c
//等待上传
 FTLoggingBean *logging = [FTLoggingBean new];
    logging.measurement = @"Test";
    logging.content = @"TestLoggingBackground";
    [[FTMobileAgent sharedInstance] loggingBackground:logging];
```       
 
```objective-c 
//立即上传
  FTLoggingBean *logging = [FTLoggingBean new];
    logging.measurement = @"Test";
    logging.content = @"TestLogging";
    [[FTMobileAgent sharedInstance] loggingImmediate:logging callBack:^(NSInteger statusCode, id  _Nullable responseObject) {
        NSLog(@"statusCode = %ld",(long)statusCode);
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showResult:statusCode==200?@"success":@"fail"];
        });
    }];
```

### 3.上报对象数据  
* background方法 

```objective-c
/**
上报对象。         数据库存储
@param name      对象名称 当前对象的名称，同一个分类下，对象名称如果重复，会覆盖原有数据
@param deviceUUID    设备UUID
@param tags          自定义标签
@param classStr              对象分类 当前对象的分类，分类值用户可自定义
*/

-(void)objectBackground:(NSString *)name deviceUUID:(nullable NSString *)deviceUUID tags:(nullable NSDictionary *)tags classStr:(NSString *)classStr;
``` 

* immediate 方法   

```objective-c
//单条
/**
上报对象。         立即上传
@param name      对象名称 当前对象的名称，同一个分类下，对象名称如果重复，会覆盖原有数据
@param deviceUUID    设备UUID
@param tags          自定义标签
@param classStr              对象分类 当前对象的分类，分类值用户可自定义
*/
-(void)objectImmediate:(NSString *)name deviceUUID:(nullable NSString *)deviceUUID tags:(nullable NSDictionary *)tags classStr:(NSString *)classStr callBack:(nullable void (^)(NSInteger statusCode, _Nullable id responseObject))callBackStatus;
//多条
-(void)objectImmediateList:(NSArray <FTObjectBean *> *)name callBack:(nullable void (^)(NSInteger statusCode, _Nullable id responseObject))callBackStatus;

```    

*  **FTObjectBean** 的属性  
 
| 属性名 | 类型 |必需|说明|
|--------|--------|--------|--------|
|    name    |   NSString     |   是     |  当前对象的名称，同一个分类下，对象名称如果重复，会覆盖原有数据      |
|    classStr |  NSDictionary      |     是  |   当前对象的分类，分类值用户可自定义    |
|    tags    | NSDictionary     |  否    |  当前对象的标签，key-value 对，其中存在保留标签  （可选）      |
|    deviceUUID   | NSString       |   否    |  设备UUID  |


* 方法使用示例   

```objective-c
[[FTMobileAgent sharedInstance] objectBackground:@"TestObjectBackground" deviceUUID:nil tags:nil classStr:@"ObjectBackground"];
```
```objective-c
    FTObjectBean *object1 = [FTObjectBean new];
    object1.name =@"TestObjectImmediateList";
    object1.classStr = @"ObjectImmediateList1";
    FTObjectBean *object2 = [FTObjectBean new];
    object2.name =@"TestObjectImmediateList";
    object2.classStr = @"ObjectImmediateList2";
    [[FTMobileAgent sharedInstance] objectImmediateList:@[object1,object2] callBack:^(NSInteger statusCode, id  _Nullable responseObject) {
        NSLog(@"statusCode = %ld",(long)statusCode);
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showResult:statusCode==200?@"success":@"fail"];
        });
    }];

```


### 4.上报事件数据 

* background方法 

```objective-c
-(void)keyeventBackground:(FTKeyeventBean *)keyevent;

```   

* immediate 方法    
 
```objective-c
-(void)keyeventImmediate:(FTKeyeventBean *)keyevent callBack:(nullable void (^)(NSInteger statusCode, _Nullable id responseObject))callBackStatus;
-(void)keyeventImmediateList:(NSArray <FTKeyeventBean *> *)keyeventList callBack:(nullable void (^)(NSInteger statusCode, _Nullable id responseObject))callBackStatus;
```   
   
*  **FTKeyeventBean** 的属性    
   
   
| 属性名 | 类型 |必需|说明|
|--------|--------|--------|--------|
|    title    |   NSString     |   是     |  关键事件标题     |
|    eventId  |  NSString      |     否  |   相关事件，__eventID 需相同   |
|    source    | NSString       |  否    |  事件的来源，保留值 datafluxTrigger 表示来自触发器    |
|    status    | FTStatus       |   否    | 事件等级和状态，info：提示，warning：警告，error：错误，critical：严重，ok：恢复，默认：info |
|    ruleId  |  NSString      |     否  |   触发器对应的触发规则id   |
|    ruleName   | NSString   |  否    |  触发器对应的触发规则名|
|    type    | NSString       |   否    | 保留值 noData 表示无数据告警|
|    ruleId  |  NSString      |     否  |   触发器对应的触发规则id   |
|    ruleName   | NSString   |  否    |  触发器对应的触发规则名|
|    actionType    | NSString  |   否    | 触发动作 |
|    tags   | NSDictionary   |  否    |  用户自定义的标签|
|    content    | NSString       |   否    | 事件内容 支持 markdown 格式|
|    suggestion  |  NSString   |   否  |   事件处理建议 支持 markdown 格式   |
|    duration   | int   |  否    |  事件的持续时间 单位为微秒|
|    dimensions    | NSString （JSONString ） |   否    | 触发维度 JSONString  例如：假设新建触发规则时设置的触发维度为 host,cpu，则该值为 ["host","cpu"] |
|    deviceUUID  |  NSString   |   否  |   设备UUID   |

 
* 方法使用示例   

```objective-c
 FTKeyeventBean *key = [FTKeyeventBean new];
 key.title = @"testKeyeventBackground";
 key.content = @"测试KeyeventBackground";
 [[FTMobileAgent sharedInstance] keyeventBackground:key];
 
``` 

```objective-c
  FTKeyeventBean *key = [FTKeyeventBean new];
  key.title = @"testKeyeventImmediate";
  key.content = @"测试KeyeventImmediate";
  [[FTMobileAgent sharedInstance] keyeventImmediate:key callBack:^(NSInteger statusCode, id  _Nullable responseObject) {
        NSLog(@"statusCode = %ld",(long)statusCode);
               dispatch_async(dispatch_get_main_queue(), ^{
                   [self showResult:statusCode==200?@"success":@"fail"];
               });
   }];
 
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
      ​       
 ```objective-c  
// FTMobileAgent  
/**
 * 设置 监控上传周期 默认为 10 秒
 */
-(void)setMonitorFlushInterval:(NSInteger)interval;
 ```
    2. 使用示例：


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

 ```objective-c    
/**
 * 开启监控同步，并设置上传时间间隔，监控类型
 * @param interval    上传周期
 * @param type        监控类型 设置后会更改config中 monitorType的设置
*/
-(void)startMonitorFlushWithInterval:(NSInteger)interval monitorType:(FTMonitorInfoType)type;
 ```
    2. 使用示例：

 ```objective-c   
  [[FTMobileAgent sharedInstance] startMonitorFlush];
  
 ```

  ```objective-c   
  [[FTMobileAgent sharedInstance] startMonitorFlushWithInterval:10 monitorType:FTMonitorInfoTypeAll];
  
  ```

### 3.关闭上传 
    1.  方法    

 ```objective-c    
/**
 * 关闭监控同步
 */
-(void)stopMonitorFlush;
 ```


    2. 使用示例：

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

 - `FTMonitorInfoTypeSensorLight`：是利用摄像头获取环境光感参数, 启动`AVCaptureSession `，获取视频流数据后可以分析得到当前的环境光强度。
 
 -  `FTMonitorInfoTypeSensorProximity` ：会开启距离传感器。当有物体靠近听筒时,屏幕会自动变暗。

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

## 十、设置页面描述、视图树描述配置
### 1. 设置是否允许描述
*  方法    

  ```objective-c
   /**
  * 设置页面和视图树是否使用描述显示
  */
  -(void)isPageVtpDescEnabled:(BOOL)enable;
  /**
  * 设置流程图是否使用描述显示
  */
  -(void)isFlowChartDescEnabled:(BOOL)enable; 

  ```

*  使用示例

  ```objective-c
    [[FTMobileAgent sharedInstance] isFlowChartDescEnabled:YES];
    [[FTMobileAgent sharedInstance] isPageVtpDescEnabled:YES];
  ```



### 2. 添加页面描述、视图树描述配置字典

* 方法    

 ```objective-c
/**
 * 设置视图描述字典 key:视图ClassName  value:视图描述
 * 替换 流程图的 name parent
 * 增加 field:page_desc 描述 autoTrack 中的 current_page_name
*/
-(void)addPageDescDict:(NSDictionary <NSString*,id>*)dict;    
 ```

 ```objective-c
/**
 * 设置视图树描述字典 key:视图树string  value:视图树描述
 * 增加 field:vtp_desc 描述 autoTrack 中的 vtp
*/
-(void)addVtpDescDict:(NSDictionary <NSString*,id>*)dict;
  
 ```

* 使用示例    

   ```objective-c    
   //设置视图描述字典
    NSDictionary *dict = @{@"DemoViewController":@"首页",
                                     @"RootTabbarVC":@"底部导航",
                                     @"UITestVC":@"UI测试",
                                     @"ResultVC":@"测试结果",
           };
    [[FTMobileAgent sharedInstance] addPageDescDict:dict];
    
    //设置视图树描述字典
    NSDictionary *vtpdict = @{@"UITabBarController/UIWindow/UITransitionView/UIDropShadowView/UILayoutContainerView/UITabBar/UITabBarButton[2]":@"second点击",
                              @"UITabBarController/UIWindow/UITransitionView/UIDropShadowView/UILayoutContainerView/UITabBar/UITabBarButton[1]":@"home点击",
    };
    [[FTMobileAgent sharedInstance] addVtpDescDict:vtpdict];
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


## 十一、常见问题
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
