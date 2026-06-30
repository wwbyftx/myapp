import Foundation
import SwiftUI

/// App 设置（用户偏好、AI 服务配置等），使用 UserDefaults 持久化。
@MainActor
@Observable
final class AppSettings {

    static let shared = AppSettings()

    /// 是否启用 AI 教练建议。
    var enableAICoach: Bool {
        didSet { defaults.set(enableAICoach, forKey: Keys.enableAI) }
    }
    /// OpenAI 兼容 API 的 BaseURL。
    var aiEndpoint: String {
        didSet { defaults.set(aiEndpoint, forKey: Keys.aiEndpoint) }
    }
    /// API Key。
    var aiAPIKey: String {
        didSet { defaults.set(aiAPIKey, forKey: Keys.aiAPIKey) }
    }
    /// 模型名。
    var aiModel: String {
        didSet { defaults.set(aiModel, forKey: Keys.aiModel) }
    }
    /// 是否启用语音播报。
    var enableVoice: Bool {
        didSet { defaults.set(enableVoice, forKey: Keys.enableVoice) }
    }
    /// 是否启用触觉反馈。
    var enableHaptics: Bool {
        didSet { defaults.set(enableHaptics, forKey: Keys.enableHaptics) }
    }

    private let defaults: UserDefaults
    private enum Keys {
        static let enableAI    = "settings.enableAI"
        static let aiEndpoint  = "settings.aiEndpoint"
        static let aiAPIKey    = "settings.aiAPIKey"
        static let aiModel     = "settings.aiModel"
        static let enableVoice = "settings.enableVoice"
        static let enableHaptics = "settings.enableHaptics"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // 注册默认值
        defaults.register(defaults: [
            Keys.enableAI: false,
            Keys.aiEndpoint: "https://api.openai.com/v1",
            Keys.aiAPIKey: "",
            Keys.aiModel: "gpt-4o-mini",
            Keys.enableVoice: true,
            Keys.enableHaptics: true
        ])
        self.enableAICoach = defaults.bool(forKey: Keys.enableAI)
        self.aiEndpoint    = defaults.string(forKey: Keys.aiEndpoint) ?? ""
        self.aiAPIKey      = defaults.string(forKey: Keys.aiAPIKey) ?? ""
        self.aiModel       = defaults.string(forKey: Keys.aiModel) ?? ""
        self.enableVoice   = defaults.bool(forKey: Keys.enableVoice)
        self.enableHaptics = defaults.bool(forKey: Keys.enableHaptics)
    }
}