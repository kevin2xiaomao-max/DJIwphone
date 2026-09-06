# DJIwphone QDC507 能力合并设计

## 目标

以现有旧版 DJIwphone 为唯一 iOS 主工程和唯一最终 App。保留原有通信界面、Bundle ID `com.kevin2xiaomao.qdc507communication`、设置、HTTP/WebSocket、Bearer Token、设备状态、短信、拨号及通话控制逻辑；从 `qdc507-ios` 迁入后续完成的 CallKit、WebRTC、音频会话和 Gateway 信令能力。

最终构建只允许生成 `DJIwphone.app` 和 `DJIwphone.ipa`。`qdc507-ios` 保留为参考仓库，不删除、不作为最终 App 构建或发布。不得修改 QDC507 真机 USB 配置或 Windows Gateway 运行状态。

## 基线与来源

- 主工程：`C:\Users\Administrator\Documents\Codex\DJIwphone`
- 上游模块来源：`C:\Users\Administrator\Documents\Codex\你的小掌柜-iOS-DEV\ios-client\Sources\QDC507WebRTC`
- 旧版 DJIwphone 来源证据：`qdc507-ios` Git 历史中的 `QDC507Communication` target，显示名为 `DJIwphone`，Bundle ID 为 `com.kevin2xiaomao.qdc507communication`。
- “你的小掌柜”主 App、Widget、经营管理功能不属于本次范围，禁止合并或改名。
- 临时 `QDC507Phone` App、`local.qdc507.phone` Bundle ID 和其独立 IPA 构建流程不进入最终工程。

## 架构

DJIwphone 保持单一 application target。现有 `GatewayClient`、`GatewayConnectionStore` 和通信界面继续作为业务入口；新能力以模块形式接入，不替换现有 UI，也不创建第二个 `@main`、第二个 application target 或第二个 scheme。

新增模块分为四层：

1. Gateway 配对与信令：复用现有 Gateway URL 和 Keychain Token，通过已有鉴权配置建立信令连接。
2. CallKit：把 Gateway 来电事件映射为系统来电，并把接听、拒接、挂断操作回传现有通话状态层。
3. WebRTC：管理前台点对点连接、SDP/ICE 交换和连接状态，不独立持有另一套用户设置。
4. 音频会话：协调 CallKit、WebRTC 和 `AVAudioSession`，保留现有 Gateway 音频契约并统一生命周期。

依赖方向为 UI → `GatewayConnectionStore` → Gateway/CallKit/WebRTC/Audio 服务。外部事件统一回到现有状态层，再驱动原界面更新。

## 数据与控制流

- 启动时从现有设置存储读取 Gateway URL，从 Keychain 读取 Bearer Token。
- 用户连接后，现有 HTTP/WebSocket 继续获取设备、短信和通话状态；WebRTC 信令使用同一 Gateway 地址和 Token。
- 收到来电事件时，状态层更新原界面，同时由 CallKit 报告系统来电。
- CallKit 或原界面触发的接听、拒接、挂断操作走同一 Gateway 通话控制接口，避免双套状态。
- 通话建立后启动 WebRTC 和音频会话；结束、断线或失败时按顺序停止媒体、释放音频会话并清理系统通话。
- Token 不写入源码、日志、构建产物或测试夹具。

## 工程与签名约束

- 工程名、application target 和共享 scheme 统一为 `DJIwphone`。
- App 显示名为 `DJIwphone`。
- Bundle ID 固定为 `com.kevin2xiaomao.qdc507communication`。
- 保留自动签名配置及已有签名字段，不引入临时 App 的 `local.qdc507.phone`。
- 只允许一个 `@main` App 入口。
- WebRTC 依赖必须链接到 DJIwphone target，并在真机构建产物中按其链接方式正确嵌入或解析。

## 错误处理

- Gateway URL、Bearer Token、HTTP、WebSocket 和信令错误继续通过现有状态层显示，敏感 Token 不进入错误文本。
- WebRTC/CallKit 初始化失败不得导致 App 启动崩溃；应回落到现有电话/短信界面并显示可诊断状态。
- 重复来电、重复挂断、断网和信令乱序必须幂等处理。
- 音频会话激活失败必须终止媒体连接并保留可恢复的 Gateway 状态。

## 测试

- 为配对配置、Bearer Token 请求、信令事件解析、通话状态映射、CallKit 操作路由和音频生命周期编写单元测试。
- 保留并运行现有 Gateway 配置与音频契约测试。
- 运行模拟器 XCTest 和 DJIwphone scheme 构建。
- 运行无签名 iphoneos Release 构建，确认只有一个 application product。
- Windows 本机不执行任何会访问或修改 QDC507 USB、ADB、串口、驱动或 Gateway 进程的测试。

## CI 与 IPA 硬性验收

GitHub Actions 只构建 `DJIwphone` scheme，并只上传一个名为 DJIwphone 的 IPA artifact。上传步骤必须依赖以下所有检查成功：

1. Release-iphoneos 目录中恰好找到一个 App，名称必须为 `DJIwphone.app`。
2. IPA 中恰好存在 `Payload/DJIwphone.app`，不得包含第二个 `.app`。
3. `Info.plist` 存在且可解析；`CFBundleIdentifier` 必须等于 `com.kevin2xiaomao.qdc507communication`，`CFBundleExecutable` 必须非空。
4. `Payload/DJIwphone.app/<CFBundleExecutable>` 必须存在、可执行、大小超过最低门槛，并由 `file` 识别为 arm64 Mach-O executable。
5. 使用 `otool -L` 检查主程序依赖；所有非系统动态依赖必须能在 App 的 `Frameworks` 目录解析。若 WebRTC 为静态链接，则通过链接清单和符号/产物体积验证，不强制要求动态 Framework。
6. App 目录和 IPA 文件均设置最低体积门槛。门槛按实际成功 Release 构建校准，但必须明确拒绝约 56KB 的空壳产物；当前 IPA 下限为 256 KiB，并应在 WebRTC 真正静态链接后根据真实产物提高。
7. `unzip -t` 必须成功，IPA 清单必须输出到 workflow 日志并保存为随 artifact 一起上传的校验报告。
8. 任一检查失败立即以非零状态退出；上传步骤不得运行。

## 发布验收

- 推送 DJIwphone 主仓库后手动触发新的 iOS device workflow。
- 等待 workflow 全部 job 成功。
- 读取 artifact 元数据，确认仅有一个 DJIwphone artifact，下载并核对真实文件大小。
- 再次离线解压 artifact，核对 Payload、Info.plist、Bundle ID、主 Mach-O 和 Frameworks 清单。
- 只有上述检查全部通过，才能报告构建完成。云端成功不能替代产物验收。
