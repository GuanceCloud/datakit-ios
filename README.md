
# Dataflux-SDK-iOS
[Dataflux-SDK-iOS-Demo](https://github.com/CloudCare/dataflux-sdk-ios-demo)   

**FTMobileSDK**

![Cocoapods platforms](https://img.shields.io/cocoapods/p/FTMobileAgent)
![Cocoapods](https://img.shields.io/cocoapods/v/FTMobileSDK)
![Cocoapods](https://img.shields.io/cocoapods/l/FTMobileSDK)

**基本要求**    
 
**iOS 10.0**及以上 
  
## 一、 导入SDK
   你可以使用下面方法进行导入：
### 1. 直接下载下来安装
1. 从 [GitHub](https://github.com/CloudCare/dataflux-sdk-ios) 获取 SDK 的源代码。	 
2. 将 SDK 源代码导入 App 项目，并选中 `Copy items if needed`。    
    直接将 **FTMobileSDK** 整个文件夹导入项目。
3. 添加依赖库：项目设置 `Build Phase` -> `Link Binary With Libraries` 添加：`UIKit` 、 `Foundation` 、`libz.tbd`，如果监控项开启且抓取网络数据，则需要添加 `libresolv.9.tbd`。


### 2. 通过 CocoaPods 导入

1. 配置 `Podfile` 文件。    
    
  ```objective-c
  target 'yourProjectName' do

  # Pods for your project
   pod 'FTMobileSDK'    
     
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
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:@"Your App metricsUrl"];
    config.monitorInfoType = FTMonitorInfoTypeAll;
     //启动 SDK
    [FTMobileAgent startWithConfigOptions:config];
    return YES;
}
```

## 三、FTMobileConfig 配置

### 1. FTMobileConfig 初始化方法   


  ```objective-c  
   /** 
    * @method 指定初始化方法，设置 metricsUrl 配置  不需要进行请求签名
    * @param metricsUrl FT-GateWay metrics 写入地址
    * @return 配置对象
    */
   - (instancetype)initWithMetricsUrl:(nonnull NSString *)metricsUrl;  
  ```
 
### 2.配置 app_id 开启 RUM
 	
  1. 设置 appid
   
   **dataflux rum** 应用唯一 ID 标识，在 DataFlux 控制台上面创建监控时自动生成。设置**appid**后，RUM 才能开启。
   
  
  2. RUM 设置采集率
 
 ``` objective-c
 /**
 * 采样配置，属性值：0或者100，100则表示百分百采集，不做数据样本压缩。默认：100
 */
 @property (nonatomic, assign) int samplerate;
 ```   

 **注意**： 开启 **RUM** 后，日志中将不采集 Crash 信息，Crash 信息会采集到 **RUM** 中。

### 3.设置日志相关    
- enableSDKDebugLog 打印日志    

   在 **debug** 环境下，设置 `FTMobileConfig` 的 `enableSDKDebugLog` 属性。
   
   ```objective-c
    config.enableSDKDebugLog = YES; //打印日志
   ```

   
- enableTrackAppCrash 采集崩溃日志 （[崩溃分析](#1-关于崩溃日志分析)） 
 
  ```objective-c 
  /**
   *设置是否需要采集崩溃日志 默认为NO
   */
   @property (nonatomic, assign) BOOL enableTrackAppCrash;
  ```    
   **注意**： 开启 **RUM** 后，日志中将不采集 Crash 信息，Crash 信息会采集到 **RUM** 中。

     
- traceConsoleLog 采集控制台日志    

   一般情况下， 因为 NSLog 的输出会消耗系统资源，而且输出的数据也可能会暴露出App里的保密数据， 所以在发布正式版时会把这些输出全部屏蔽掉。此时开启采集控制台日志，也并不能抓取到工程里打印的日志。建议使用 [日志写入接口](#主动上报日志方法) 来上传想查看的日志。
 
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
-  networkTrace 设置网络追踪
   
 - 设置网络追踪，开启网络请求信息采集
   
 ``` objective-c   
 /**
 * 设置网络请求信息采集 默认为NO
 */
@property (nonatomic, assign) BOOL networkTrace;

 ```    
          
 - 设置网络请求信息采集时 使用链路追踪类型 
   
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
           
### 4. 设置X-Datakit-UUID
 `X-Datakit-UUID` 是 SDK 初始化生成的 UUID, 应用清理缓存后(包括应用删除)，会重新生成。
 `FTMobileConfig` 配置中，开发者可以强制更改。更改方法：

  ```objective-c
   [config setXDataKitUUID:@"YOUR UUID"];
  ```
   
### 5. 采集数据配置

   配置 `FTMobileConfig` 的 `FTMonitorInfoType` 属性。可采集的类型如下：    

 ```objective-c
/**
 * @enum  TAG 中的设备信息
 *
 * @constant
 *  FTMonitorInfoTypeBattery  - 电池使用率
 *  FTMonitorInfoTypeMemory   - 内存总量、使用率
 *  FTMonitorInfoTypeCpu      - CPU 占用率
 *  FTMonitorInfoTypeBluetooth- 蓝牙对外显示名称
 *  FTMonitorInfoTypeLocation - 地理位置信息
 *  FTMonitorInfoTypeFPS      - 每秒传输帧数
 */
typedef NS_OPTIONS(NSUInteger, FTMonitorInfoType) {
    FTMonitorInfoTypeAll          = 0xFFFFFFFF,
    FTMonitorInfoTypeBattery      = 1 << 1,
    FTMonitorInfoTypeMemory       = 1 << 2,
    FTMonitorInfoTypeCpu          = 1 << 3,
    FTMonitorInfoTypeBluetooth    = 1 << 4,
    FTMonitorInfoTypeLocation     = 1 << 5,
    FTMonitorInfoTypeFPS          = 1 << 6,
};
      
 ```

  
### 6.设置 UI 卡顿、ANR 事件采集


 - enableTrackAppUIBlock 采集UI卡顿事件

   通过 **fps** 采集 **fps** 小于 10 的事件； 
     
   ```
   /**
   * 默认为NO
   * 设置是否需要采集卡顿
   * 采集fps小于10
   */
   @property (nonatomic, assign) BOOL enableTrackAppUIBlock;
   ```
     
- enableTrackAppANR  采集ANR卡顿无响应事件

     通过 **runloop** 采集主线程卡顿事件。
   
   ```
   /**
   * 默认为NO
   * 设置是否需要采集卡顿
   * runloop采集主线程卡顿
   */
   @property (nonatomic, assign) BOOL enableTrackAppANR;
   ```
 
 采集的数据会上传到 **RUM** 与日志中。  
   
## 四、参数

### 1. FTMobileConfig  可配置参数：

|          字段          |     类型     |            说明             |                是否必须                |
| :------------------: | :--------: | :-----------------------: | :--------------------------------: |
|      metricsUrl      |  NSString  |  FT-GateWay metrics 写入地址  |                 是                  |
|      appid      |  NSString  |  dataflux rum应用唯一ID标识，在DataFlux控制台上面创建监控时自动生成。  |                 否（开启RUM 必选）                  |

|      enableSDKDebugLog       |    BOOL    |        设置是否允许打印日志         |              否（默认NO）               |
|    enableDescLog     |    BOOL    |       设置是否允许打印描述日志        |              否（默认NO）               |
|   monitorInfoType    | NS_OPTIONS |     [采集数据](#5-采集数据配置)     |                 否                  |
|   enableTrackAppCrash   |    BOOL    |       设置是否需要采集崩溃日志      |              否（默认NO）              |
|   enableTrackAppANR   |    BOOL    |       采集ANR卡顿无响应事件      |              否（默认NO）              |
|   enableTrackAppUIBlock   |    BOOL    |       采集UI卡顿事件      |              否（默认NO）              |
|   traceServiceName   |    NSString    |       设置日志所属业务或服务的名称      |              否（默认dataflux sdk）              |
|   traceConsoleLog   |    BOOL    |       设置是否需要采集控制台日志      |              否（默认NO）              |
|   eventFlowLog   |    BOOL    |       设置是否采集页面事件日志  |              否（默认NO）              |
|   networkTrace   |    BOOL    |       设置网络请求信息采集  |              否（默认NO）              |
| samplerate |float|采样采集率|否（默认100）|
|   networkTraceType   |    FTNetworkTrackType    |   设置网络请求信息采集时 使用链路追踪类型 | 否（默认Zipkin）         |


## 五、主动上报日志方法

**上传机制** : 将数据存储到数据库中，等待时机进行上传。数据库存储量限制在 5000 条，如果网络异常等原因导致数据堆积，存储 5000 条后，会丢弃新传入的数据。    


* 上传日志方法 

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


## 六、用户的绑定与注销 

### 1. 用户绑定：

```objective-c
  /**
绑定用户信息
 @param Id       用户Id
*/
- (void)bindUserWithUserID:(NSString *)Id;
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
[[FTMobileAgent sharedInstance] bindUserWithUserID:userId];
```

```objective-c
//登出后 注销当前用户
[[FTMobileAgent sharedInstance] logout];
```



## 七、常见问题

### 1. 关于崩溃日志分析
在开发时的 **Debug** 和 **Release** 模式下，**Crash** 时捕获的线程回溯是被符号化的。
而发布包没带符号表，异常线程的关键回溯，会显示镜像的名字，不会转化为有效的代码符号，获取到的 **crash log** 中的相关信息都是 16 进制的内存地址，并不能定位崩溃的代码，所以需要将 16 进制的内存地址解析为对应的类及方法。

#### 利用命令行工具解析 **Crash**     
需要的文件：    

1. 需要从 **DataFlux** 下载 **SDK** 采集上传的崩溃日志。下载后将后缀改为 **.crash**。
2. 需要 **App** 打包时产生的 **dSYM** 文件，必须使用当前应用打包的电脑所生成的 **dSYM** 文件，其他电脑生成的文件可能会导致分析不准确的问题，因此每次发包后建议根据应用的**版本号**或 **dSYM** 文件的 **UUID** 来对应保存 **dSYM** 文件。以备解析时，根据后台日志 tag 中的 `application_UUID` 对应的 **UUID** 来找到对应 **dSYM** 文件。
3. 需要使用 **symbolicatecrash**，**Xcode** 自带的崩溃分析工具，使用这个工具可以更精确的定位崩溃所在的位置，将0x开头的地址替换为响应的代码和具体行数。 
   
    > 查找 **symbolicatecrash** 方法  
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



   
   
 




