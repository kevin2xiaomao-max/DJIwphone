import Foundation
import SwiftUI
import Observation

// MARK: - 应用偏好设置（对齐 Android SharedPreferences 字段）

@Observable
final class AppSettings {
    static let shared = AppSettings()

    private let ud = UserDefaults.standard

    var shopName: String {
        didSet { ud.set(shopName, forKey: "shop_name") }
    }
    var ownerName: String {
        didSet { ud.set(ownerName, forKey: "owner_name") }
    }
    var monthGoal: Double {
        didSet { ud.set(monthGoal, forKey: "month_goal") }
    }
    /// system / light / dark
    var themeMode: String {
        didSet { ud.set(themeMode, forKey: "theme_mode") }
    }
    var todoReminderEnabled: Bool {
        didSet { ud.set(todoReminderEnabled, forKey: "todo_reminder") }
    }
    var expiryReminderEnabled: Bool {
        didSet { ud.set(expiryReminderEnabled, forKey: "expiry_reminder") }
    }
    var voiceLanguage: String {
        didSet { ud.set(voiceLanguage, forKey: "voice_language") }
    }
    var avatarEmoji: String {
        didSet { ud.set(avatarEmoji, forKey: "avatar_emoji") }
    }
    var avatarImageData: Data? {
        didSet {
            if let avatarImageData { ud.set(avatarImageData, forKey: "avatar_image_data") }
            else { ud.removeObject(forKey: "avatar_image_data") }
        }
    }
    var appThemeName: String {
        didSet { ud.set(appThemeName, forKey: "app_theme_name") }
    }

    init() {
        shopName = ud.string(forKey: "shop_name") ?? "天福便利店"
        ownerName = ud.string(forKey: "owner_name") ?? "掌柜"
        monthGoal = ud.object(forKey: "month_goal") as? Double ?? 120000.0
        themeMode = ud.string(forKey: "theme_mode") ?? "system"
        todoReminderEnabled = ud.object(forKey: "todo_reminder") as? Bool ?? true
        expiryReminderEnabled = ud.object(forKey: "expiry_reminder") as? Bool ?? true
        voiceLanguage = ud.string(forKey: "voice_language") ?? "普通话"
        avatarEmoji = ud.string(forKey: "avatar_emoji") ?? "👨🏻‍💼"
        avatarImageData = ud.data(forKey: "avatar_image_data")
        appThemeName = ud.string(forKey: "app_theme_name") ?? "Blue Purple"
    }

    var colorScheme: ColorScheme? {
        switch themeMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var themeModeLabel: String {
        switch themeMode {
        case "light": return "浅色"
        case "dark": return "深色"
        default: return "跟随系统"
        }
    }
}
