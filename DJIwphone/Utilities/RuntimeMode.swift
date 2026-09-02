import Foundation

enum RuntimeMode {
    /// Mock 数据仅限 SwiftUI Preview，或开发者显式设置 XZG_UI_PREVIEW_DEMO=1 的 UI 验收进程。
    /// 普通 Debug Simulator 和所有真机构建始终返回 false。
    static var allowsMockData: Bool {
        #if DEBUG && targetEnvironment(simulator)
        let environment = ProcessInfo.processInfo.environment
        return environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
            || environment["XZG_UI_PREVIEW_DEMO"] == "1"
        #else
        return false
        #endif
    }
}

