# 健身 AI 教练（iOS）

一款用 iPhone 摄像头做实时动作分析、并给出口头 / 震动 / 文字反馈的健身 App。完全在设备端做姿态识别（Apple Vision），可选地把训练概况发给大模型以获得自然语言教练建议。

## 功能

- 实时摄像头 + 人体姿态骨架叠加
- 支持动作：**深蹲**、**俯卧撑**、**平板支撑**（规则化算法，可继续扩展）
- 实时反馈：关节角度、身体线对齐、深度、计数 / 保持时长
- 多模态反馈：语音播报（系统 TTS）、触觉（Core Haptics）、画面顶部 Banner
- 训练记录：本地持久化（SwiftData）
- 可选：训练结束后调用 OpenAI 兼容接口生成自然语言建议

## 技术栈

| 维度 | 选型 |
|---|---|
| 语言 / UI | Swift 5.10 + SwiftUI |
| 最低系统 | iOS 17.0（使用 3D 人体姿态） |
| 摄像头 | AVFoundation |
| 姿态识别 | Vision：`VNDetectHumanBodyPose3DRequest`（3D）+ `VNDetectHumanBodyPoseRequest`（2D 回退） |
| 语音 / 触觉 | AVSpeechSynthesizer / Core Haptics |
| 持久化 | SwiftData |
| 大模型 | OpenAI 兼容 Chat Completion（用户自填 Key） |
| 工程化 | XcodeGen 生成 `.xcodeproj` |

## 目录结构

```
iospro/
├── README.md
├── project.yml                       # XcodeGen 配置
├── .gitignore
├── .github/
│   └── workflows/
│       └── build.yml                 # GitHub Actions：云端构建模拟器 / 真机 .app
└── iospro/
    ├── iosproApp.swift               # @main 入口
    ├── ContentView.swift             # 根 TabView
    ├── Info.plist
    ├── Assets.xcassets/
    ├── Models/                       # Exercise / PoseFrame / Feedback / WorkoutSession
    ├── Services/                     # Camera / PoseDetection / FormAnalyzer /
    │                                 #   Feedback / AI / WorkoutStore / AppSettings
    ├── ViewModels/                   # WorkoutViewModel / HistoryViewModel
    └── Views/                        # Home / CameraWorkoutView / CameraPreview /
                                      #   PoseOverlay / FeedbackBanner / History / Settings
```

## 拿到 .app 的几种方式

### A. 在 Mac 上打开（标准流程）

```bash
brew install xcodegen
cd iospro
xcodegen generate
open iospro.xcodeproj
```

在 Xcode 中选择 Team（Signing & Capabilities），**真机运行**。模拟器没有摄像头，只能看 UI。

### B. 完全不碰 Mac：GitHub Actions 云构建

把仓库推到 GitHub 后，`.github/workflows/build.yml` 会自动跑出两个产物：

| 产物 | 用途 |
|---|---|
| `iospro-simulator.app` | 在 Mac 上 `xcrun simctl install booted <app>` 装到模拟器，或直接在 Xcode 中 run |
| `iospro-device-unsigned.ipa` | **没 Mac 用户走这条**——配合 AltStore / Sideloadly 自签后装到 iPad / iPhone（7 天有效，到期重签） |

触发方式：
- push 到 `main` / `master` / `codex/**` 分支自动构建
- 手动触发：GitHub → Actions → Build iOS App → Run workflow
- 产物在 workflow run 页面底部 **Artifacts** 下载

真机签名装到 iPad 的具体步骤：

1. iPad / iPhone 上从 App Store 免费装 [AltStore](https://altstore.io/) 或电脑上装 [Sideloadly](https://sideloadly.io/)。
2. 启动 AltStore / Sideloadly，连上 iPad，输入你的 Apple ID（仅用于自签，7 天免费）。
3. 拖入下载的 `iospro-device-unsigned.ipa` → Sideload / Install。
4. 第一次启动会提示「未受信任的企业级开发者」，到 **设置 → 通用 → VPN 与设备管理** 里信任你的 Apple ID。
5. App 7 天后到期，重连 AltStore / Sideloadly 重签即可。

> 长期分发建议申请 Apple Developer 账号（\$99/年）并配 Provisioning Profile，把 workflow 改成自动签名。

## 使用说明

1. 首次进入训练页会弹出摄像头权限授权。
2. 选择动作后，把手机**固定**（建议使用三脚架），**侧身 / 正侧对镜头**，全身入镜。
3. 画面顶部会显示动作名与状态；下方实时显示主要关节角度、次数 / 保持时长与质量分。
4. 训练中如出现姿态异常，会在画面底部弹出红色 Banner，同时发出语音与震动提示。
5. 点击「结束训练」会保存本次记录到「历史」页。
6. 在「设置」中开启「AI 教练建议」并填入 API Key，可在训练结束后获取自然语言改进建议。

### AI 教练配置

- 兼容任何 OpenAI Chat Completion 协议的接口（包括 OpenAI、Azure OpenAI、DeepSeek、Moonshot、自部署等）。
- 默认 Base URL：`https://api.openai.com/v1`
- 默认模型：`gpt-4o-mini`
- API Key 仅保存在本地 UserDefaults，不会上传到任何第三方服务（除你配置的接口本身）。

## 姿态识别原理

1. `CameraService` 采集 `CVPixelBuffer`，丢弃落后帧后推给 `PoseDetectionService`。
2. `PoseDetectionService` 优先用 `VNDetectHumanBodyPose3DRequest`（iOS 17+），失败时回退到 2D 姿态。
3. `FormAnalyzer` 根据动作类型把关节角度、身体线对齐、深度等指标转化为反馈与计数：
   - **深蹲**：髋-膝-踝夹角判断下蹲深度；肩-髋-膝夹角判断上身过度前倾。
   - **俯卧撑**：肩-肘-腕夹角判断下放幅度；肩-髋-膝夹角判断躯干是否成直线。
   - **平板支撑**：肩-髋-膝夹角是否在 170°~185°，并累计保持秒数。
4. 计数使用带滞回的有限状态机，避免抖动。

## 二次开发

- 接入更多动作：实现 `FormAnalyzer` 的新方法并在 `process(frame:)` 路由。
- 替换 / 增强 AI：修改 `AIService` 的 `response_format` 或换成图像 / 视频帧调用（推荐用多模态模型）。
- 接入 Apple Watch：把 `WorkoutSession` 同步到 HealthKit。

## 已知限制

- 3D 姿态需要 iOS 17+。更早的设备会回退到 2D 姿态，角度测量精度较低。
- 动作识别对**手机摆放位置**和**全身是否入镜**敏感，建议侧身 90° 做深蹲 / 俯卧撑，斜后方做平板。
- 规则化算法的阈值基于通用健身经验，个体差异较大，需要根据实际测试调参（在 `FormAnalyzer.swift` 中集中管理）。
- GitHub Actions 出的真机 .app 只能 7 天有效，要长期使用需申请 Apple Developer 账号配置签名。