# 1.6.0-alpha.9
1. 同 1.5.14
---
# 1.5.14
1. 新增 RUM `Resource` 数据字段 `resource_first_byte_time`、`resource_dns_time`、`resource_download_time`、`resource_connect_time`、`resource_ssl_time`、`resource_redirect_time`，支持在观测云上的优化展示和 APM 火焰图的时间对齐
2. 默认开启 `FTMobileConfig.enableDataIntegerCompatible` 
3. 新增支持通过宏定义 `FT_DISABLE_SWIZZLING_RESOURCE` 关闭 SDK 内 URLSession Method Swizzling 方法
4. 优化数据同步，添加失败重传逻辑
---
# 1.5.14-beta.3
1. 同 1.5.14-beta.1
---
# 1.5.14-beta.1
1. 新增支持通过宏定义 `FT_DISABLE_SWIZZLING_RESOURCE` 关闭 SDK 内 URLSession Method Swizzling 方法
2. 优化数据同步链路追踪手段
---
# 1.5.14-alpha.1
1. 数据同步优化，添加失败重传逻辑
2. `FTMobileConfig.enableDataIntegerCompatible` 默认开启
3. 新增 RUM Resource 数据字段 `resource_first_byte_time`、`resource_dns_time`、`resource_download_time`、`resource_connect_time`、`resource_ssl_time`、`resource_redirect_time`，在观测云上的优化展示并支持 APM 火焰图的时间对齐
---
# 1.6.0-alpha.8
1. 修复 Session Replay 快照 Record 增量比较时异常造成的快照丢失快照全量更新问题
2. 同 1.5.13 
---
# 1.5.13
1. 优化页面采集逻辑，防止特殊视图导致 RUM View 采集缺失
---
# 1.5.13-beta.1
1. 更新 ViewController viewUUID 逻辑修改，防止 RUM 添加相同 view_id 的 View
---
# 1.6.0-alpha.7
1. 获取 keyWindow 方法修改，修复在 Widget Extension 环境无法编译问题
2. 优化 Session Replay 上传条件判断、同步时内部日志输出
3. 优化 Session Replay 采集，只采集 keyWindow 逻辑修改为采集多个 window
4. 同 1.5.4 - 1.5.13-alpha.3
---
# 1.5.13-alpha.3
1. RUM View 采集优化，防止侧滑重复采集 View
2. RUM View 子页面采集逻辑调整，仅采集父视图为 UITabBarController 、UINavigationController、UISplitViewController 的子视图
---
# 1.5.13-alpha.2
1. tvOS 环境类名替换，修复使用未声明类问题
---
# 1.5.13-alpha.1
1. 优化页面采集逻辑，防止特殊视图导致 view 采集缺失
---
# 1.5.12
1. 调整文件存储路径配置，修复数据库创建失败的问题
2. 更新了 tvOS 环境的默认 `service` 和日志 `source`，分别设置为 `df_rum_tvos` 和 `df_rum_tvos_log`
3. 修复 RUM Action 事件中 `duration` 时长计算不准确的问题
---
# 1.5.12-beta.1
1. 修改 tvOS 环境默认 service 为 `df_rum_tvos`、日志 source 为 `df_rum_tvos_log`
2. RUM Action duration 时长错误修改
---
# 1.5.12-alpha.1
1. 修改 tvOS 环境文件存储路径，修复无法创建数据库问题
---
# 1.5.11
1. RUM Resource 采集优化，防止 RUM 开启 Resource 自动采集时采集 SDK 内请求
2. 修复 Widget Extension 中 skyWalking 类型链路追踪失败问题
---
# 1.5.11-beta.1
1. RUM Resource 采集优化，防止 RUM 开启 Resource 自动采集时因在 task.resume() 时获取 task.currentRequest 为 nil 导致采集 SDK 内请求问题
2. 修复 Widget Extension 中 skyWalking 类型链路追踪失败问题
---
# 1.5.10
1. 支持通过 `FTTraceConfig.traceInterceptor` 拦截 Request 自定义 Trace,
   通过 `FTRumConfig.resourcePropertyProvider` 添加 RUM Resource 自定义属性
2. 修复动态添加全局属性方法在多线程访问下的异常问题
3. 优化 WebView 传入数据信息
---
# 1.5.10-beta.3
1. SDK 版本信息内容传输优化
2. 优化处理 Resource 数据过程，防止多线程使用 NSMutableData 异常、NSURLResponse 强转 NSHTTPURLResponse 异常
---
# 1.5.10-beta.2
1. 调整 WebView RUM 传入数据格式
---
# 1.5.10-beta.1
1. `traceInterceptor` 与 `resourcePropertyProvider` block 别名添加 `FT` 前缀、返回值 NSDictionary 添加类型声明
2. 修复动态添加全局属性方法多线程访问异常问题
---
# 1.5.10-alpha.1
1. 支持全局 `traceInterceptor` 与 `resourcePropertyProvider`
---
# 1.5.9
1. 新增支持通过 `FTURLSessionDelegate.traceInterceptor` block 拦截 `URLRequest`，进行自定义链路追踪、更改链路中 spanId 与 traceId
2. RUM Resource 支持采集通过 swift async/await URLSession API 发起的网络请求
3. 修复 LongTask 与 Anr 关联 View 错误问题
---
# 1.5.9-beta.3
1. 修复 LongTask 与 Anr 关联 View 错误问题
---
# 1.5.9-beta.2
1. 修复 Resource 采集未过滤 SDK 内部 URL 的问题
2. 修复 swift package 编译配置错误问题
---
# 1.5.9-beta.1
1. 同 1.5.9-alpha.1
---
# 1.5.9-alpha.1
1. 新增支持自定义 Trace 关联 RUM
2. 支持采集通过 swift async/await URLSession API 发起的 Resource 数据
---
# 1.5.8
1. 增加 tvOS 支持
2. 新增 RUM 条目数量限制功能，支持通过 `FTRUMConfig.rumCacheLimitCount` 来限制 SDK 最大缓存条目数据限制，支持通过 `FTRUMConfig.rumDiscardType` 设置来指定丢弃新数据或丢弃旧数据
3. 新增支持通过 `FTMobileConfig.enableLimitWithDbSize` 限制总缓存大小功能，开启之后
   `FTLoggerConfig.logCacheLimitCount` 及 `FTRUMConfig.rumCacheLimitCount` 将失效，
   支持通过 `FTMobileConfig.dbDiscardType` 设置 db 废弃策略，
   支持通过 `FTMobileConfig.dbCacheLimit` 设置 db 缓存限制大小
4. 添加配置信息调试日志输出
---
# 1.5.8-beta.2
1. 同 1.5.8-beta.1
---
# 1.5.8-beta.1
1. db 限制总缓存大小功能优化
2. `FTRUMConfig.rumCacheLimitCount` 默认值改为 100_1000
---
# 1.5.8-alpha.2
1. 增加 tvOS 支持
2. 新增支持通过 `FTMobileConfig.enableLimitWithDbSize` 开启 db 限制大小功能，
   支持通过 `FTMobileConfig.dbDiscardType` 设置 db 废弃策略，
   支持通过 `FTMobileConfig.dbCacheLimit` 设置 db 缓存限制大小
3. 添加配置信息调试日志输出
---
# 1.5.8-alpha.1
1. 新增 RUM 条目数量限制功能，支持通过 `FTRUMConfig.rumCacheLimitCount` 来限制 SDK 最大缓存条目数据限制，支持通过 `FTRUMConfig.rumDiscardType` 设置来指定丢弃新数据或丢弃旧数据
---
# 1.5.7
1. 支持通过 `FTRUMConfig.freezeDurationMs` 设置卡顿检测阀值
2. 优化 SDK 的 `shutDown` 方法，避免主线程同步等待导致的卡顿或 WatchDog 崩溃
---
# 1.5.7-beta.1
1. 同 1.5.7-alpha.1、1.5.7-alpha.2
---
# 1.5.7-alpha.2
1. 替换 longtask 检测时间范围设置参数 `blockDurationMs` 为 `freezeDurationMs`
---
# 1.5.7-alpha.1
1. 添加设置 longtask 检测时间范围的方法
2. 优化 SDK 的 `shutDown` 方法，避免主线程同步等待导致的卡顿或 WatchDog 崩溃
---
# 1.5.6
1. 支持使用 `FTMobileConfig.compressIntakeRequests` 对同步数据进行 deflate 压缩配置
2. RUM 添加 `addAction:actionType:property` 与 `startAction:actionType:property:` 方法，优化 RUM Action 采集逻辑
3. 修复使用 NSFileHandle 废弃 api 导致的崩溃问题
---
# 1.5.6-beta.1
1. 同 1.5.5-alpha.1
2. 修复使用 NSFileHandle 废弃 api 导致的崩溃问题

---
# 1.5.5
1. 修复 `FTResourceMetricsModel` 中数组越界导致的崩溃问题
---
# 1.5.5-beta.1
1. 同 1.5.2-hotfix.2
---
# 1.5.5-alpha.1
1. 添加对 SDK 内部数据请求压缩的支持
2. RUM 添加 `addAction:actionType:property` 与 `startAction:actionType:property:` 方法，优化 RUM Action 采集逻辑
---
# 1.5.4
1. 添加全局、log、RUM globalContext 属性动态设置方式
2. 添加清除数据方法，支持删除所有尚未上传至服务器的数据
3. 调整同步间歇支持的最大时间间隔至 5000 毫秒
---
# 1.5.4-beta.1
1. 同 1.5.4-alpha.1-1.5.4-alpha.4
2. SDK `shutDown` 方法内部关闭顺序调整
3. RUM `addError` 方法参数 `stack` 允许为空
---
# 1.5.4-alpha.4
1. 调整同步间歇支持的最大时间间隔至 5000 毫秒
2. 全局、log、RUM globalContext 属性动态设置方法修改为类方法
3. 废弃 `FTMobileConfig.version` 属性
4. 优化动态 tags 赋值的时机
---
# 1.5.4-alpha.3
1. 添加清除数据方法，支持删除所有尚未上传至服务器的数据
2. 优化 SDK `shutDown` 方法，由实例方法改为类方法，防止测试环境断言抛错
3. 调整同步间歇支持的最大时间间隔至 500 毫秒
4. 补充内部错误提示日志
---
# 1.5.4-alpha.2
1. 优化动态 tags 赋值的时机
---
# 1.5.4-alpha.1
1. 添加全局、log、RUM globalContext 属性动态设置方式
---
# 1.6.0-alpha.6
1. 修复增量快照中 `updates` 数据丢失问题
2. 优化获取 `keyWindow` 方法
---
# 1.6.0-alpha.5
1. 修复 Wireframes 增量判断时 `unrecognized selector` 崩溃问题
2. 优化 Session Replay 添加 try Catch 防护
---
# 1.6.0-alpha.4
1. 同 1.5.3
---
# 1.5.3
1. 修复因属性修饰符使用不当引发的内存访问错误导致的崩溃问题
2. 使用内部警告日志替换 `FTSwizzler` 中方法签名验证断言
3. 优化采集数据的小数精度
---
# 1.6.0-alpha.3
1. 补充 `UISegment` 选定选项时的背景屏蔽
2. `FTSessionReplayConfig` 添加 `additionalNodeRecorders` 私有方法，辅助 react-native 自定义视图采集
---
# 1.6.0-alpha.2
1. Session Replay 显示细节优化，text 隐私权限显示效果修改
2. 修复 CGColor 释放导致的闪退问题
3. 修复 launch_cold 丢失问题
___
# 1.6.0-alpha.1
1. 新增 Session Replay 功能
2. RUM-View 自动采集逻辑优化，修复 View 采集中断缺失问题
___
# 1.5.2-hotfix.2
1. 修复 `FTResourceMetricsModel` 中数组越界崩溃的问题
---
# 1.5.2
1. 修复 Xcode 16 编译缺少 `#include <arm/_mcontext.h>` 头文件问题
2. 自动采集 RUM-Resource 时，过滤掉直接从本地缓存获取或获取类型未知的 Resource，防止采集重复
3. 修复 UITabBarController 子视图 loadingTime 计算逻辑
---
# 1.5.2-beta.1
1. 同 1.5.2-alpha.1 - 1.5.2-alpha.3
2. 修复 UITabBarController 子视图 loadingTime 计算逻辑
---
# 1.5.2-alpha.3
1. 修复 Xcode 16 编译缺少 `#include <arm/_mcontext.h>` 头文件问题
---
# 1.5.2-alpha.2
1. 自动采集 RUM-Resource 过滤条件增加，过滤掉资源获取类型未知的 Resource
---
# 1.5.2-alpha.1
1. 自动采集 RUM-Resource 时，过滤掉直接从本地缓存获取的 Resource，防止采集重复
---
# 1.5.1
1. 修复行协议数据转义算法，解决因换行符导致数据同步失败问题
2. 优化错误类型为 `network_error` 的错误信息，统一使用英文描述网络请求错误码
3. 优化数据同步逻辑，修复多线程访问已释放 `uploadDelayTimer` 导致的崩溃问题
4. 修复采集崩溃信息时 OC 与 C 字符串转换时编码格式错误导致的崩溃问题
---

# 1.5.1-beta.2
1. 优化数据同步逻辑，修复多线程访问已释放 `uploadDelayTimer` 导致的崩溃问题
2. 修复采集崩溃信息时 OC 与 C 字符串转换时编码格式错误导致的崩溃问题
---
# 1.5.1-beta.1
1. 同 1.5.1-alpha.1、1.5.1-alpha.2
---
# 1.5.1-alpha.2
1. 优化错误类型为 `network_error` 的错误信息，统一使用英文描述网络请求错误码
---
# 1.5.1-alpha.1
1. 修复行协议数据转义算法，解决因换行符导致数据同步失败问题
---
# 1.5.0
1. RUM resource 网络请求添加 remote ip 地址解析功能
2. 添加行协议 Integer 数据兼容模式，处理 web 数据类型冲突问题
3. 日志添加自定义 status 方法
4. 日志数据写入优化、数据同步优化
5. 对传入 SDK 的 NSDictionary 类型参数进行格式处理防止转换 json 失败造成数据丢失
---
# 1.5.0-beta.1
1. 同 1.5.0-alpha.2
---
# 1.5.0-alpha.2
1. 修复日志数据写入时互斥锁未初始化造成访问冲突问题
2. 行协议处理格式错误数据逻辑优化
3. sdk_data_id 算法修改
4. 对传入 SDK 的 NSDictionary 类型参数格式处理防止转换 json 失败造成数据丢失
---
# 1.5.0-alpha.1
1. RUM resource 网络请求添加 remote ip 地址解析功能
2. 添加行协议 Integer 数据兼容模式，处理 web 数据类型冲突问题
3. 日志添加自定义 status 方法
4. 日志数据写入优化、数据同步优化
---
# 1.4.14
1. 修复 `FTSwizzler` 内访问已被销毁的 Class 对象而导致的内存访问错误崩溃
2. 修复向 SDK 传递的 NSDictionary 类型参数实际上是可变对象时可能引发的数据一致性和操作冲突问题
---

# 1.4.14-beta.1
1. 同 1.4.14-alpha.2
---
# 1.4.14-alpha.2
1. 修复传入变量属性时，可能会导致的冲突问题
---
# 1.4.14-alpha.1
1. 修复 swizzle 方法与其他库 swizzle 方法冲突问题

---
# 1.4.13
1. RUM LongTask、Anr 采集优化，修复 LongTask 堆栈信息采集不准确问题，新增支持采集致命卡顿
2. 修复 `FTSwizzler` 内因多线程同时操作 NSMutableSet 造成的崩溃
3. 修复打包 SDK Framework info.plist 中版本信息缺失问题
4. 修复自定义 NSURLSession 未设置 delegate 时 Resource 的性能指标采集失败问题
5. SDK 内部日志转化为文件功能优化，新增指定文件路径方法

---
# 1.4.13-beta.1
1. LongTask、Anr 采集优化，文件操作添加线程保护
2. 修复 NSURLSession 未设置 delegate 时 metrics 采集失败问题
3. SDK 内部日志转化为文件 backup 文件名赋值错误修复

---
# 1.4.13-alpha.1
1. LongTask、Anr 采集优化，修复 LongTask 堆栈信息不准确问题
2. 修复多线程访问造成 Resource 数据 swizzle 崩溃问题
3. Framework info.plist 版本信息补充
4. sdk_data_id 算法修改
5. SDK 内部日志转化为文件功能优化，新增指定文件路径方法

---
# 1.4.12
1. 修复 SDK 调用注销方法 shutDown 产生的内存泄漏问题
2. 修复采集 RUM-Resource 时与其他库冲突导致崩溃问题
3. 修复崩溃采集 UncaughtExceptionHandler 未传递问题
4. 修复多次初始化 SDK 造成的数据异常

---
# 1.4.12-beta.1
1. 修复注销SDK后产生的内存泄漏问题
2. 修复采集 RUM-Resource 时与其他库冲突导致崩溃问题
3. 处理完 UncaughtException 传递 UncaughtExceptionHandler
4. 修复重复配置 SDK 造成的数据异常

---
# 1.4.12-alpha.1
1. 数据同步、日志写入优化
2. Framework info.plist 版本信息补充
3. sdk_data_id 算法修改
---

# 1.4.11
1. 新增支持数据同步参数配置，请求条目数据，同步间歇时间，以及日志缓存条目数
2. 新增内部日志转文件方法
3. 日志关联 RUM 数据获取错误修复
4. 耗时操作优化
5. 修复 WebView jsBridge 时产生的崩溃，对 WebView 引用改为弱引用
---

# 1.4.11-beta.1
1. 修复 WebView jsBridge 时产生的崩溃，对 WebView 引用改为弱引用
---
# 1.4.11-alpha.2
1. 数据同步时超时时间设置无效修复
2. 避免符号冲突方法名称修改
2. 调试日志输出格式优化
---

# 1.4.11-alpha.1
1. 新增支持数据同步参数配置，请求条目数据，同步间歇时间，以及日志缓存条目数
2. 新增内部日志转文件方法
3. 日志关联 RUM 数据获取错误修复
4. 耗时操作优化

---
# 1.4.10-beta.2
1. 修复数据同步失败问题

---
# 1.4.10-beta.1
1. 同 1.4.10-alpha.1-1.4.10-alpha.2
2. 调整隐私清单引用

---
# 1.4.10-alpha.2
1. 修复数据同步失败问题
2. 修复多线程访问造成 Resource 数据 swizzle 崩溃问题

---
# 1.4.10-alpha.1
1. 添加隐私清单

---
# 1.4.9-beta.5
1. WebView 传入数据时间精度适配

---
# 1.4.9-beta.4
1. 同 1.4.9-alpha.7 ，.c文件头文件引用调整

---
# 1.4.9-alpha.7
1. 补充缺失的头文件，修复编译失败问题

---
# 1.4.9-beta.3
1. 拦截 URLSession 采集数据时使用 `currentRequest` 替换 `originalRequest`，修复一些场景下用户自定义采集 `RUM-resource` 规则时数据类型转换失败问题

---
# 1.4.9-beta.2
1. 优化 RUM-Resource 自动采集逻辑，修复一些场景下采集异常问题
2. 通过 `FTURLSessionDelegate` 自定义链路追踪时,自定义优先级高于自动追踪

---
# 1.4.9-beta.1
1. 同 1.4.9-alpha.1 - 1.4.9-alpha.6
2. longtask、anr 发生时间赋值错误修复
3. RUM-Resource 自动采集与使用`FTURLSessionDelegate`自定义采集兼容处理

---
# 1.4.9-alpha.6
1. WebView 传入数据时间精度适配
2. SkyWalking propagation header service 参数调整
2. 修复 ANR 重复采集、优化 Error 错误信息、线程回溯

---
# 1.4.9-alpha.5
1. 新增不关联 RUM 时获取 Trace 链路请求头的方法
2. 数据上传时 BOOL 类型数据格式处理修改

---
# 1.4.9-alpha.4
1. `RUM-View` 新增指标 `view_update_time`

---
# 1.4.9-alpha.3
1. `RUM-View.is_active` 页面活跃状态修改为指标

---
# 1.4.9-alpha.2
1. `RUM-Action` 中启动事件时间赋值错误修复

---
# 1.4.9-alpha.1
1. 修复 arm64e 符号翻译失败问题

---
# 1.4.8-beta.1
1. 同 1.4.8-alpha.5、 调试日志输出调整

---
# 1.4.8-alpha.5
1. 修复 `RUM-view.duration` 时间过长问题
2. RUM-ResourceError `error_type` 对应值调整为 `network_error`

---
# 1.4.8-alpha.4
1. 修复由 block 创建 IMP 时添加多余参数 SEL 导致的崩溃问题
2. 修复采样率算法
3. 优化调试日志输出、UUID String 格式更改

---
# 1.4.8-alpha.3
1. 新增 dataway 公网上传数据逻辑
2. 添加上传数据唯一标识
3. 修复 resource duration 负值问题、resource_first_byte 计算逻辑修改
4. 自动采集 HTTP Resource 逻辑修改，解决 URLSession 创建在 SDK 初始化完成之前时该 URLSession 无法采集问题

---
# 1.4.8-alpha.2
1. RUM Session 过期逻辑修改，同步重置 view，修复 APP 进入后台 HTTP 请求悬挂导致的 RUM-View 持续时间过长问题
2. 自动采集 HTTP Resource 逻辑修改
3. 新增自定义采集 HTTP Resource 功能
4. 优化 RUM-ResourceError 错误信息描述

---
# 1.4.8-alpha.1
1. 新增自定义 TraceHeader 功能
2. 配置 FTRumConfig 时设置 `resourceUrlHandler` 替换 FTMobileAgent `-isIntakeUrl:` 方法
3. 修复多个 URLSession resource 自定义数据覆盖问题

---
# 1.4.7-beta.4
1. 数据上传逻辑优化

---
# 1.4.7-beta.3
1. 数据上传逻辑优化，防止递归导致栈溢出崩溃

---
# 1.4.7-beta.2
1. 解决 URLSession 创建在 SDK 之前时该 URLSession 请求无法采集问题

---
# 1.4.7-beta.1
1. 同 1.4.7-alpha.2、1.4.7-alpha.1

---
# 1.4.7-alpha.2
1. RUM LongTask 采集优化
2. RUM Resource 支持用户自定义资源属性

---
# 1.4.7-alpha.1
1. 解决 RUM View timeSpend 异常问题
2. 开启 View 自动采集时 app Enter background、foreground 同步 view start、stop

---
# 1.4.6-beta.1
1. 同 1.4.6-alpha.6

---
# 1.4.6-alpha.6
1. 枚举命名修改

---
# 1.4.6-alpha.5
1. RUM AddError 方法添加 state 参数
2. 注销用户方法 -unbindUser 替换 -logout

---
# 1.4.6-alpha.4
1. app Become、Resign Active 同步 view start、stop

---

# 1.4.6-alpha.3
1. 支持高刷设备的 FPS 计算错误修复

---
# 1.4.6-alpha.2
1. 处理 UITabBarController 子视图加载时间异常问题

---
# 1.4.6-alpha.1
1. 数据上传处理空值数据逻辑修改

---
# 1.4.5-beta.1
1. 修复 RUM View 时间赋值错误问题

---
# 1.4.5-alpha.1

1. Webview RUM 接入数据格式调整

---
# 1.4.4-beta.1
1. 自定义日志打印控制台格式调整

---
# 1.4.4-alpha.1
1. 移除日志自动采集功能，添加自定义日志打印在控制台开关
2. 添加自定义 env

---
# 1.4.3-beta.1
1. 同 1.4.3-alpha.1

---

# 1.4.3-alpha.1
1. 修复 RUM 数据丢失问题
2. RUM 中 resource、error、long_task 缺失 action 相关字段补充

---

# 1.4.2-alpha.3
1. FTSDKCore 基础库支持自定义数据库路径和名称

---
# 1.4.2-alpha.2
1. 删除 dataKitUUID

---
# 1.4.2-alpha.1
1. 解决打包无 module 问题
2. 修复已知 BUG

---
# 1.4.1-alpha.3
1. 修复 RUM resource 数据格式错误问题

---
# 1.4.1-alpha.2
1. RUM resource 中 resource_type 赋值修改

---
# 1.4.1-alpha.1
1. 修复 RUM resource 处理 response header 时未考虑大小写兼容问题

---

# 1.4.0-beta.3
1. 新增 SDK 注销 API

---
# 1.4.0-beta.2
1. podspec source_files 调整，解决软连接文件导致的 duplicate 警告

---
# 1.4.0-beta.1
1. 新增 Widget Extension 数据采集功能
2. 网络链路追踪自动追踪优化
3. 添加 SPM 支持，添加支持 carthage 打包 FTMobileExtension
4. 修复已知 BUG

---
# 1.3.12-alpha.4
1. macos error监控项支持采集设备电量使用率

---
# 1.3.12-alpha.3
1. 项目结构调整, FTSDKCore 支持macOS

---
# 1.3.12-alpha.2
1. 包结构调整,sdk 支持 platform 版本修改

---
# 1.3.12-alpha.1
1. 包结构调整,基础功能支持macOS

---
# 1.3.11-alpha.1
1. 修复已知 BUG
2. NSURLProtocol protocolClasses 设置优化
3. 添加 SPM 支持，添加支持 carthage 打包 FTMobileExtension

---
# 1.3.10-beta.3
1. 修复内存泄漏问题
2. 修复其他已知 BUG

---
# 1.3.10-alpha.7
1. 修复多线程数组copy导致的内存泄漏
2. 修复已知 BUG

---
# 1.3.10-alpha.6
1. 修复日志采集时产生的内存泄漏
2. SDK 支持版本修改，iOS 支持10.0及以上，macOS支持10.13及以上

---
# 1.3.10-beta.2
1. 修复 Error 监控采集属性字段错误问题

---

# 1.3.10-beta.1
1. 添加 intakeUrl 采集 Resource 过滤方法
2. Resource,Action,View,Error,LongTask,Logger 支持添加扩展参数
3. config 配置 service 参数调整
4. 修复已知 BUG

---

# 1.3.10-alpha.3
1. config 配置 service 参数调整
2. 修复从应用切换器进入 APP 导致的启动时长统计异常问题
3. Action Type 新增 launch_warm 适配 iOS15 后 APP 启动前进行了预热
4. 修复 dispatch_semaphore_t 优先级反转问题

---
# 1.3.10-alpha.1
1. 添加 intakeUrl 采集 Resource 过滤方法
2. Resource,Action,View,Error,LongTask,Logger 支持添加扩展参数

---
# 1.3.8-beta.4
1. 修改 DDtrace Header Propagation 规则

---

# 1.3.8-beta.3
1. 文件引用格式修复

---

# 1.3.8-beta.2
1. 修复获取 GMT 时间时修改了全局 timezone 问题
2. 内部数据上传 URLSession 使用自定义 session 替换 sharedSession

---
# 1.3.8-beta.1
1. 外部接入 RUM 补充自定义 actionType 方法
2. 添加 iPhone14 设备信息适配
3. 添加 active_pre_warm 判断启动是否进行了预热

---
# 1.3.8-alpha.3
1. 测试用例修改
---

# 1.3.8-alpha.2
1. 添加 iPhone14 设备信息适配
2. 添加 active_pre_warm 判断启动是否进行了预热

---

# 1.3.8-alpha.1
1. 外部接入 RUM 补充自定义 actionType 方法

---

# 1.3.7-beta.1
1. 用户绑定数据扩展
2. 崩溃日志符号化

---

# 1.3.7-alpha.4
1. FTDeviceMetricsMonitorType type值适配

---

# 1.3.7-alpha.4
1. userLogout 用户email缓存清理

---
# 1.3.7-alpha.3
1. 解决可能遗漏冷启动事件的问题

---

# 1.3.7-alpha.2
1. 用户绑定数据扩展
2. import 引用方式错误调整

---
# 1.3.7-alpha.1
1. 用户绑定数据扩展

---
# 1.3.6-beta.2
1. 解决潜在遗漏启动时部分数据的问题

---
# 1.3.6-beta.1
1. 配置监控项，采集 fps、memory、cpu 相关数据
2. 崩溃日志、卡顿日志采集内容格式调整

---

# 1.3.6-alpha.4
1. 公开的头文件补充

---

# 1.3.6-alpha.3
1. cpu 采集字段名称修改、cpu数据赋值错误修改

---

# 1.3.6-alpha.2
1. cpu 采集规则修改

---

# 1.3.6-alpha.1
1. 配置监控项，采集fps、memory、cpu相关数据
2. 崩溃日志、卡顿日志格式调整，符号化缺失信息补充

---

# 1.3.5-beta.4
1. 解决 resource error 导致的 action 重复写入问题。

---

# 1.3.5-beta.3
1. 解决数据中空字符串导致上传失败问题。

---

# 1.3.5-beta.2
1. 解决在 flutter、reactNative 中启动事件采集错误的问题。

---

# 1.3.5-beta.1
1. 修正使用 kvo 导致 hook 失败影响项目正常流程的问题。
2. 过滤格式错误的数据。
3. SDK 内部 URL 过滤 bug 修改。

---

# 1.3.5-alpha.4
1. SDK 内部 URL 过滤 bug 修改。

---
# 1.3.5-alpha.3
1. 过滤格式错误的数据。
2. SDK 内部日志使用 os_log 替换 NSLog。

---
# 1.3.5-alpha.2
1. SDK 内部 NSLog 删除。

___
# 1.3.5-alpha.1
1. 解决使用 kvo 导致 hook 失败影响项目正常流程的问题。

___
# 1.3.4-beta.2
1. 静态库公开头文件缺失补充
2. FTMobileSDK scheme shared

___

# 1.3.4-beta.1
1. 提升测试用例覆盖率

---

# 1.3.4-alpha.3
1. 添加onCreateView方法记录view加载时长

___
# 1.3.4-alpha.2
1. 启动事件计算规则修改

2. RUM 页面 viewReferrer 记录规则修改

___
# 1.3.4-alpha.1
1. 启动事件计算规则修改

2. RUM 页面 viewReferrer 记录规则修改

___
# 1.3.3-alpha.5
1. trace enableAutoTrace 错误修改

___
# 1.3.3-alpha.4
1. DDtrace header 修改

___
# 1.3.3-alpha.3
1. NetworkTraceType 默认为 DDtrace,DDtrace traceid 算法修改

2. 外部接入 rum api 调整

___
# 1.3.3-alpha.2
1. 支持 Skywalking 、W3c TraceParent、

2. Zipkin 添加 single header 支持

3. 外部接入 rum api 调整

___

# 1.3.3-alpha.1
1. 支持 Skywalking 、W3c TraceParent、

2. Zipkin 添加 single header 支持

___

# 1.3.2-alpha.1
1. 添加设置全局 tag 方法。

___

# 1.3.1-alpha.11
1. 修复获取公共属性多线程访问时产生的 bug

___
# 1.3.1-alpha.10
1. 修改 RUM 传入字符串数据长度为0时的错误
2. rum 常量使用调整

___
# 1.3.1-alpha.9
1. RUM、Trace 数据整理，提供对外调用 API
2. 解决 RUM 数据错误问题

---

# 1.3.1-alpha.8
1. RUM、Trace 数据整理，提供对外调用 API

---
# 1.3.1-alpha.7
1. RUM、Trace 数据整理，提供对外调用 API
2. RUM Config 添加 enableTraceUserResource 方法

---
# 1.3.1-alpha.6
1. RUM、Trace 数据整理，提供对外调用 API

---
# 1.2.8-alpha.7
1. unused code整理

2. RUM 、Trace 数据处理方法调整

---
# 1.2.8-alpha.4
1. unused code整理

2. RUM 、Trace 数据处理方法调整

---
# 1.2.8-alpha.3
1. unused code整理

2. RUM 、Trace 数据处理方法调整

---
# 1.2.8-alpha.2
1. unused code整理

2. RUM 数据处理方法调整

---
# 1.2.8-alpha.1
1. unused code整理

2. RUM 数据处理方法调整

---
# 1.2.7-alpha.3
1. RUM view 数据采集，参数 viewController 传入为 nil 导致的 bug 修改

2. 追踪 ID 算法修正

---
# 1.2.7-alpha.1
1. RUM view 数据采集，参数 viewController 传入为 nil 导致的 bug 修改

---
# 1.2.6-alpha.2
1. RUM 用户自设全局 tag 功能添加

2. 获取 IP address bug 修改

---
# 1.2.6-alpha.1
1. RUM 用户自设全局 tag 功能添加

---
# 1.2.5-alpha.2
1. 日志废弃策略添加

2. APP 生命周期监控优化

3. UISegmentedControl 点击事件采集 bug 修改

4. 页面 load 时长 bug 修改

5. 获取 IP address bug 修改

---
# 1.2.5-alpha.1
1. 日志废弃策略添加

2. APP 生命周期监控优化

3. UISegmentedControl 点击事件采集bug修改

4. 页面 load 时长 bug 修改

---
# 1.2.4-alpha.2
1. 解决 fishhook 在 iOS14.5 及以上设备上出现的崩溃问题

---
# 1.2.3-alpha.1
1. 多线程懒加载导致的 BUG 修改

---
# 1.2.2-alpha.1
1. logger 添加过滤条件

---
# 1.2.1-alpha.7
1. 抽出公共方法，设置子包

2. podspec 修改兼容osx，头文件引用修改

---
# 1.2.1-alpha.6
1. 抽出公共方法，设置子包

2. podspec 修改兼容osx，头文件引用修改

---
# 1.2.1-alpha.5
1. 抽出公共方法，设置子包

2. podspec 语法错误修改，子包移除引用主包的头文件

---
# 1.2.1-alpha.4
1.抽出公共方法，设置子包
2. podspec 语法错误修改，子包移除引用主包的头文件

---
# 1.2.1-alpha.3
1. 抽出公共方法，设置子包
2. podspec 语法错误修改

---
# 1.2.1-alpha.2
1. 抽出公共方法，设置子包

---
# 1.2.1-alpha.1
1. swizzle 方法修改

---

# 1.2.0-alpha.5
1. Config 配置修改

2. Logger 与 Trace 数据支持绑定 RUM

---
# 1.2.0-alpha.4
1. Config 配置修改

2. Logger 与 Trace 数据支持绑定 RUM

---
# 1.2.0-alpha.3
1. Config 配置修改

2. Logger 与 Trace 数据支持绑定 RUM

---
# 1.2.0-alpha.2
1. Config 配置修改
2. Logger 与 Trace 数据支持绑定 RUM

---
# 1.2.0-alpha.1
1. Config 配置修改
2. Logger 与 Trace 数据支持绑定 RUM

---

# 1.1.0-alpha.10
1. RUM 数据调整
2. 测试用例添加

---
# 1.1.0-alpha.9
1. RUM 数据调整
2. 测试用例添加

---
# 1.1.0-alpha.8
1. RUM 数据调整
2. 测试用例添加

---
# 1.1.0-alpha.7
1. RUM 数据调整
2. 测试用例添加

---
# 1.1.0-alpha.6
1. RUM 数据调整
2. resource_size添加响应头大小

---
# 1.1.0-alpha.5
1. RUM 数据调整

---
# 1.1.0-alpha.4
1. RUM 数据调整

---
# 1.1.0-alpha.3
1. RUM 数据调整

---
# 1.1.0-alpha.2
1. RUM 数据调整

---
# 1.1.0-alpha.1
1. RUM 数据调整

---

# 1.0.4-alpha.12
1. 子线程ping 检测卡顿，进行 freeze 采集
2. config 采集卡顿配置项改为 enableTrackAppFreeze

---
# 1.0.4-alpha.11
1. tag app_identified 改为 app_identifiedid
2. freeze 采集，避免一次卡顿多次写入

---

# 1.0.4-alpha.10
1. tag、filed keys调整

---

# 1.0.4-alpha.9
1. tag、field、measurement值 添加转译字符处理

---
# 1.0.4-alpha.8
1. 时间单位微秒、纳秒使用错误修改
2. int越界修改

---
# 1.0.4-alpha.7
1. 时间单位微秒、纳秒使用错误修改

---
# 1.0.4-alpha.6
1. 网络链路数据采集上报

---

# 1.0.4-alpha.5
1. RUM 数据采集
2. 卡顿、ANR采集

---
# 1.0.4-alpha.4
1. RUM 数据采集
2. 卡顿、ANR采集

---

# 1.0.4-alpha.3
1. RUM 数据采集
2. 卡顿、ANR采集
3. config 配置是否开启采集UIBlock、ANR

---

# 1.0.4-alpha.2
1. 网络错误率、时间开销采集
2. 卡顿、ANR采集
3. config 配置是否开启采集UIBlock、ANR

---
# 1.0.4-alpha.1
1. 网络错误率、时间开销采集
2. 卡顿、ANR采集

---
# 1.0.3-beta.2
1. 修正若干错误问题，发布稳定版本

---

# 1.0.3-beta.1
1. 修正错误，提升性能

---

# 1.0.3-alpha.11
1. 日志批量写入数据库
2. 日志__content 大小限制

---

# 1.0.3-alpha.10
1. 采样率调整为网络请求信息采集采样率
2. 使用 XML 文件设置页面描述与视图树描述

---

# 1.0.3-alpha.9
1. response解析修改
2. logging类型添加新字段

---

# 1.0.3-alpha.8
1. 根据content-type 处理 body 内容
2. 网络追踪 __content 大小限制
3. bug修改

---
# 1.0.3-alpha.7
1. 根据content-type 处理 body 内容
2. 网络追踪 __content 大小限制
3. bug修改

---

# 1.0.3-alpha.6
1. object __name拼接应用bundleID
2. 网络追踪spanID改为UUID

---
# 1.0.3-alpha.5
1. logging、object、keyevent上报类型添加
2. 增加网络信息采集链路追踪、日志采集、事件日志采集
3. 设置NSLog release下不打印，避免数据库在主线程写入,验证token请求结果处理逻辑修改

---
# 1.0.3-alpha.4
1. logging、object、keyevent上报类型添加
2. 增加网络信息采集链路追踪、日志采集、事件日志采集
3. dSYMUUID获取方法修改
4. SDK 内部log循环 bug 修改

---
# 1.0.3-alpha.2
1. logging、object、keyevent上报类型添加
2. 增加网络信息采集链路追踪、日志采集、事件日志采集
3. dSYMUUID获取方法修改

---
# 1.0.3-alpha.1
1. logging、object、keyevent上报类型添加
2. 增加网络信息采集链路追踪、日志采集、事件日志采集

---
# 1.0.2-alpha.26
1. 采集率添加
2. 获取崩溃日志方法添加
3. object、keyevent、logging上传方法添加

---
# 1.0.2-alpha.25
1. 获取蓝牙设备已连接列表修改

---

# 1.0.2-alpha.24
1. 添加拦截https请求
2. 已连蓝牙设备key修改

---

# 1.0.2-alpha.23
1. 网络速率获取优化
2. 监控项上传开启未设置监控类型不上传
3. 距离传感器距离状态获取修改

---

# 1.0.2-alpha.22
1. 流程图 duration 拼接i处理
2. page_desc默认赋值N/A修改

---
# 1.0.2-alpha.21
1. 增加UIView分类，添加可设置是否在vtp拼接点击NSIndexPath的属性、添加描述Vtp属性
2. 添加开关判断是否替换添加描述
3. 添加描述日志开关

---
# 1.0.2-alpha.19
1. vtp_desc、page_desc field字段添加
2. 添加addVtpDescDict、addPageDescDict方法
3. 引用头文件错误修改

---
# 1.0.2-alpha.17
1. vtp改为tag vtp_id改为field
2. UITabBar的点击事件无vtp调整

---
# 1.0.2-alpha.16
1. 添加vtp_id tag

---
# 1.0.2-alpha.15
1. 网络请求错误率获取失败修改

---
# 1.0.2-alpha.12
1. 监控项周期上传方法添加设置监控项类型方法
2. autotrack抓取点击事件过滤方法修改

---

# 1.0.2-alpha.11
1. product移除
2. event_id由field改为tag
3. 一些tag的名称调整

---

# 1.0.2-alpha.5
1. latitude、longitude 由tag改为filed
2. 设置location更新距离为200米

---

# 1.0.2-alpha.4
1. vtp 由tag改为filed
2. 增加event_id
3. 流程图flowId初始化bug修改

---
# 1.0.2-alpha.1
1. 监控项拓展
2. product设置，对应全埋点、流程图、监控项上传指标名

---
# 1.0.1-alpha.22
1. 方法名拼写错误修改
2. 黑白名单判断逻辑修改

---
# 1.0.1-alpha.21
1. trackImmediate与trackImmediateList方法主线程回调
2. CLLocationManagerDelegate回调逻辑处理

---
# 1.0.1-alpha.20
1. 数据存储结构优化，网络上传模块优化
2. 日志打印优化，全埋点优化
3. Agent添加startLocation方法

---
# 1.0.1-alpha.19
1. 页面流程图指标集名称校验修改
2. 位置信息-直辖市省市一致

---
# 1.0.1-alpha.18
1. 页面流程图指标集名称添加校验
2. 错误码拼写错误修改
3. 上传时参数拼接bug修改

---
# 1.0.1-alpha.17
1. 获取应用名bug修改

---
# 1.0.1-alpha.16
1. 解决SDK获取不到版本号问题
2. 实时获取的监控项由tag转变为field,流程图设备tag数据移除

---

# 1.0.1-alpha.15
1. 网络框架parameters拼接方法优化
2. 网速获取bug修改
3. Location添加国家

---
# 1.0.1
1.上报流程图

---
# 1.0.0

1.用户自定义埋点
2.FT Gateway 数据同步

