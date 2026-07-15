# Enum Map Bounds Safety

> 本功能遵循 `../development/feature-workflow.md`。Feature Note 记录本次枚举映射数组方法化、非法值降级与验收结果。

## Background

- Requirement: SDK 中存在以枚举值直接访问 C 数组的 `Map[index]` 写法，公开 API、配置反序列化或外部持久化数据可传入越界值并导致宿主应用崩溃。
- Current behavior: 合法枚举映射正确；越界值会读取数组边界外内存。`StatusCustom` 也没有对应的静态数组元素。
- Target behavior: 删除枚举映射数组，使用基于 `switch` 的类型化转换函数；合法输入行为不变，非法输入使用已确认的默认值且不崩溃。

## Data Findings

- `FTStatusStringMap`、`FTEnvStringMap`、`MonitorFrequencyMap` 和 `AppStateStringMap` 均存在公开 API、公开配置或外部数据可达的下标访问。
- Session Replay 的三个隐私映射数组由公开配置属性进入 `debugDescription`；非法属性值会造成越界访问。
- `FTBatteryStateStringMap` 来源为系统状态，不属于公开输入，但仍存在未来系统枚举值或异常状态导致越界的可能。
- `FTNetworkTraceStringMap` 没有任何调用点，直接删除，不提供替代转换函数。
- `FTInternalConstants.h` 通过 Core 模块间接可见；本次移除其中的数组声明，但不改变正式公开配置类、枚举和业务 API。

## Scope

In scope:

- [x] 删除 9 个枚举映射数组，其中 `FTNetworkTraceStringMap` 仅删除。
- [x] 使用类型化转换函数替换其余 8 个数组的全部调用点。
- [x] 覆盖日志、环境、监控频率、AppState、Session Replay 隐私和电池状态的合法及非法值。
- [x] 更新测试夹具，确保源码和测试中不再出现目标 `Map[index]`。

Out of scope:

- [x] 不改变正式公开 API 签名或枚举定义。
- [x] 不改变日志过滤顺序、采样、属性合并、RUM 关联、存储或上传协议。
- [x] 不改变 Network Trace 类型的实际 header 注入逻辑。

## Implementation Notes

- `FTStringFromLogStatus` 保留 `info/warning/error/critical/ok/debug` 映射；未知枚举回退 `info`，`StatusCustom` 缺少自定义字符串时使用 `unknown`。
- `FTStringFromEnv` 对未知值回退 `prod`；`FTIntervalFromMonitorFrequency` 对未知值回退 `0.5` 秒。
- `FTStringFromAppState` 归属 RUM 协议类型，对未知值回退 `unknown`。
- `FTStringFromAppState` 需要被 RUM Manager、Session Handler 和测试夹具复用；声明放在非 Public 的 `FTRUMManager.h`，不放入公开的 `FTRumDatasProtocol.h`。
- Session Replay 的文本、触摸、图片隐私转换函数保持模块私有，分别回退 `MaskAll`、`Hide`、`MaskAll`。
- 电池状态转换函数保持模块私有，未知值回退 `Unknown`。
- 所有转换函数使用 `switch`，函数内部不得再次引入数组下标映射。
- `FTLogger` 的配置校验、控制台打印、开关、级别过滤、采样、RUM 关联和写入顺序保持不变。

## Todo

- [x] 实现 Core、RUM 和 Session Replay 转换函数。
- [x] 替换 SDK 与测试辅助代码中的数组调用。
- [x] 补充合法映射和非法值回归测试。
- [x] 执行静态搜索、单元测试、CI 脚本与 CocoaPods 分发验证。

## Acceptance Checklist

- [x] 目标映射数组的声明、定义和下标访问全部移除。
- [x] 所有合法枚举返回与修改前相同的值。
- [x] 负数、上界外值及无符号极大值不会导致崩溃，并使用约定 fallback。
- [x] `StatusCustom` 的正常自定义字符串保持不变，缺失字符串时使用 `unknown`。
- [x] 日志、RUM、Session Replay、Extension 恢复和监控频率相关回归测试通过。
- [x] 自动化测试和分发验证结果已记录。

## Verification Results

- 静态搜索：目标 9 个数组名称在 `Sources/` 与 `Examples/` 中无残留，生产源码中无枚举 `Map[index]` 调用；`git diff --check` 通过。
- 边界回归：9 个 focused tests 通过，覆盖全部合法值、负数、上界外值、`NSIntegerMax`/`NSUIntegerMax`，以及公开日志、Env、RUM AppState、监控频率、Session Replay、电池状态和 Extension 恢复路径。
- Swift Package：`swift build` 通过。
- CocoaPods：`bash scripts/verify-distribution-packages.sh --only cocoapods` 通过，完成 iOS、macOS、tvOS podspec validation。
- CI 脚本：`sh JenkinsTestingBash.sh` 执行了 iOS 全量 834 个测试，1 个跳过，33 个失败（其中 2 个 unexpected），脚本退出 65，因 `set -e` 未继续 tvOS。失败集中在需要真实 `APP_ID`、`ACCESS_SERVER_URL`、`TRACE_URL`、App Group entitlement 或网络环境的既有用例；本功能新增及相关回归用例均通过。

## Known Limitations

- 本地没有 CI 所需的真实服务参数与 App Group entitlement，无法把上述环境依赖型全量用例验证为绿色；未发现由本次枚举映射改动引入的失败。

## Open Questions

- 无。`StatusCustom` 缺失字符串的 fallback 已确认为 `unknown`；非法 AppState 使用现有 `unknown`。

## Follow-up Logic Contract Updates

- [x] fallback 与兼容约束已记录在本 Feature Note；现有 Logic Contract 描述的日志过滤、采样、RUM 数据流、Session Replay 正常路径和公开默认值均未改变，无需修改其正常流程契约。
