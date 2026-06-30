import SwiftUI

@MainActor
struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @State private var showAPIKey = false
    @State private var testResult: String?

    var body: some View {
        @Bindable var s = settings
        NavigationStack {
            Form {
                Section("反馈") {
                    Toggle("语音播报", isOn: $s.enableVoice)
                    Toggle("触觉反馈", isOn: $s.enableHaptics)
                }

                Section {
                    Toggle("启用 AI 教练建议", isOn: $s.enableAICoach)
                } header: {
                    Text("AI 教练（可选）")
                } footer: {
                    Text("开启后，训练结束时会把你这一组的概况（动作、次数、时长、平均分、常见错误）发送到你配置的 OpenAI 兼容接口，获取一段自然语言的改进建议。")
                }

                if settings.enableAICoach {
                    Section("API 配置") {
                        TextField("Base URL", text: $s.aiEndpoint)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        HStack {
                            Group {
                                if showAPIKey {
                                    TextField("API Key", text: $s.aiAPIKey)
                                } else {
                                    SecureField("API Key", text: $s.aiAPIKey)
                                }
                            }
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            Button {
                                showAPIKey.toggle()
                            } label: {
                                Image(systemName: showAPIKey ? "eye.slash" : "eye")
                            }
                            .buttonStyle(.borderless)
                        }
                        TextField("模型", text: $s.aiModel)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        if let r = testResult {
                            Text(r)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("关于") {
                    LabeledContent("版本", value: "0.1.0")
                    LabeledContent("姿态识别", value: "Apple Vision")
                    LabeledContent("最低系统", value: "iOS 17.0")
                }
            }
            .navigationTitle("设置")
        }
    }
}

#Preview {
    SettingsView()
        .environment(AppSettings.shared)
}
