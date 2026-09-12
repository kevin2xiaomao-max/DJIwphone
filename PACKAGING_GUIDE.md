# DJIwphone 0.3.0 打包交付指南

## 工程身份

- 唯一 iOS App target / scheme：`DJIwphone`
- Bundle ID：`com.kevin2xiaomao.qdc507communication`
- 版本：`0.3.0`
- 入口工程：`project.yml`（由 XcodeGen 生成项目）
- 业务代码、AppIcon、Keychain Token、WebSocket 自动连接、短信 compose/send、`/api/sms/send`、`sendSMS(...)`、拨号及 CallKit 控制均位于唯一 `DJIwphone` target。

## 环境要求

- macOS + Xcode 15 或更高版本（建议使用当前稳定版）
- iOS 17 SDK
- XcodeGen：`brew install xcodegen`
- Swift Package Manager：由 Xcode 自动解析 `stasel/WebRTC` 151.0.1
- 网络可访问 GitHub，以获取 `WebRTC` Swift package
- 不要求 Apple Developer 付费团队、TestFlight、PushKit entitlement；小白签可在导出后处理。

## 首次准备

在仓库根目录执行：

```bash
xcodegen generate
xcodebuild -project DJIwphone.xcodeproj -scheme DJIwphone -resolvePackageDependencies
```

之后打开 **`DJIwphone.xcodeproj`**，选择唯一 scheme：`DJIwphone`。

## 构建

Simulator XCTest：

```bash
xcodebuild test -project DJIwphone.xcodeproj -scheme DJIwphone \
  -destination 'platform=iOS Simulator,name=<本机可用设备>'
```

Simulator build：

```bash
xcodebuild build -project DJIwphone.xcodeproj -scheme DJIwphone \
  -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO
```

Device Release（供小白签处理）：

```bash
xcodebuild build -project DJIwphone.xcodeproj -scheme DJIwphone \
  -sdk iphoneos -configuration Release \
  -derivedDataPath build/Device CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
```

App 位于：`build/Device/Build/Products/Release-iphoneos/DJIwphone.app`。

未签名 IPA（小白签输入）：

```bash
mkdir -p ipa/Payload
cp -R build/Device/Build/Products/Release-iphoneos/DJIwphone.app ipa/Payload/
(cd ipa && zip -qry ../DJIwphone.ipa Payload)
```

## 产物检查

```bash
/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' build/Device/Build/Products/Release-iphoneos/DJIwphone.app/Info.plist
/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' build/Device/Build/Products/Release-iphoneos/DJIwphone.app/Info.plist
test -f build/Device/Build/Products/Release-iphoneos/DJIwphone.app/Assets.car
```

应分别得到 Bundle ID `com.kevin2xiaomao.qdc507communication` 和版本 `0.3.0`。IPA 内必须只有 `Payload/DJIwphone.app`，不得出现第二个 App。

## 常见问题

- `No such module WebRTC`：确认已执行 `xcodebuild -project DJIwphone.xcodeproj -scheme DJIwphone -resolvePackageDependencies`，并检查 Xcode 能访问 GitHub package。
- 找不到 Simulator：先执行 `xcrun simctl list devices available`，使用实际存在的 UDID/名称。
- AppIcon/Assets.car 缺失：确认打开的是 project，并重新运行 `xcodegen generate` 后构建。
- 小白签不接受未签名包：先使用上面的 `.app` 或 `.ipa`，由签名工具重新签名；不要修改 Bundle ID。

## 交给打包人员（极简版）

1. 工程路径：`C:\Users\Administrator\Documents\Codex\DJIwphone`
2. commit：`b5dcf032104260f5cb89b3560050242b7f700951`
3. 依赖：`brew install xcodegen && xcodegen generate && xcodebuild -project DJIwphone.xcodeproj -scheme DJIwphone -resolvePackageDependencies`
4. 打包：打开 `DJIwphone.xcodeproj`，scheme 选 `DJIwphone`，执行 Device Release 命令并按上文生成 IPA
5. 最终 IPA：仓库根目录 `DJIwphone.ipa`
6. 必验：Bundle ID `com.kevin2xiaomao.qdc507communication`，版本 `0.3.0`
