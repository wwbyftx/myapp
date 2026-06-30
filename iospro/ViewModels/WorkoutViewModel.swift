import AVFoundation
import Foundation
import SwiftUI

/// 训练页面的状态机与数据流中心。
@MainActor
@Observable
final class WorkoutViewModel {

    // MARK: - 状态

    enum Status {
        case idle
        case requestingPermission
        case ready
        case running
        case finished
    }

    private(set) var status: Status = .idle
    private(set) var permissionDenied: Bool = false
    private(set) var lastError: String?

    let exercise: ExerciseKind

    /// 摄像头服务。
    let camera = CameraService()
    /// 姿态识别服务。
    private let poseDetector = PoseDetectionService()
    /// 规则化分析器。
    private var analyzer: FormAnalyzer
    /// 反馈输出。
    private let feedbackService = FeedbackService()
    /// AI 服务（可选）。
    private let aiService = AIService()
    /// 设置。
    private let settings: AppSettings

    // MARK: - 派生 UI 状态

    private(set) var repCount: Int = 0
    private(set) var holdSeconds: Double = 0
    private(set) var primaryAngle: Float?
    private(set) var stateLabel: String = "准备"
    private(set) var qualityScore: Double = 100
    private(set) var recentFeedback: [FormFeedback] = []
    private(set) var lastFrame: PoseFrame?
    private(set) var aiAdvice: AIService.Advice?
    private(set) var loadingAI: Bool = false
    private(set) var totalFeedbackCount: Int = 0

    private var startedAt: Date?
    private var finishedAt: Date?
    private var lastFrameAt: Date = .now
    private var lastQualitySum: Double = 0
    private var qualitySamples: Int = 0
    private var frequentIssues: [String] = []
    private var issueCounter: [String: Int] = [:]
    private var didStop: Bool = false
    private var didStart: Bool = false

    private var frameTask: Task<Void, Never>?

    init(exercise: ExerciseKind, settings: AppSettings = .shared) {
        self.exercise = exercise
        self.settings = settings
        self.analyzer = FormAnalyzer(exercise: exercise)
    }

    // MARK: - 生命周期

    func start() async {
        status = .requestingPermission
        let granted = await CameraService.requestAuthorization()
        guard granted else {
            permissionDenied = true
            status = .idle
            return
        }
        do {
            try camera.configureIfNeeded()
        } catch {
            lastError = error.localizedDescription
            status = .idle
            return
        }
        // 摄像头帧回调发生在后台线程，桥接到 MainActor
        camera.onPixelBuffer = { [weak self] buffer, _ in
            Task { @MainActor [weak self] in
                self?.handlePixelBuffer(buffer)
            }
        }
        camera.start()
        startedAt = .now
        didStart = true
        status = .running
    }

    /// 幂等：多次调用只会保存一次。
    /// 未真正开始（拒绝授权 / 摄像头配置失败）则不保存。
    func stopAndSave() {
        guard !didStop else { return }
        didStop = true
        camera.stop()
        camera.onPixelBuffer = nil
        frameTask?.cancel()
        frameTask = nil
        guard didStart, let start = startedAt else {
            status = .finished
            return
        }
        finishedAt = .now
        let avg = qualitySamples > 0 ? (lastQualitySum / Double(qualitySamples)) : qualityScore
        WorkoutStore.shared.save(
            exercise: exercise,
            startedAt: start,
            endedAt: finishedAt ?? .now,
            reps: repCount,
            holdSeconds: holdSeconds,
            feedbackCount: totalFeedbackCount,
            avgQuality: avg
        )
        status = .finished
    }

    /// 训练结束时调用 AI 教练。
    func requestAIAdvice() async {
        guard settings.enableAICoach, !settings.aiAPIKey.isEmpty else { return }
        loadingAI = true
        defer { loadingAI = false }
        let summary = WorkoutSummary(
            exerciseName: exercise.displayName,
            duration: (finishedAt ?? .now).timeIntervalSince(startedAt ?? .now),
            reps: repCount,
            holdSeconds: holdSeconds,
            avgQuality: qualityScore,
            frequentIssues: frequentIssues
        )
        do {
            let advice = try await aiService.generateAdvice(
                endpoint: settings.aiEndpoint,
                apiKey: settings.aiAPIKey,
                model: settings.aiModel,
                summary: summary
            )
            self.aiAdvice = advice
        } catch {
            self.lastError = error.localizedDescription
        }
    }

    // MARK: - 帧处理

    private func handlePixelBuffer(_ buffer: CVPixelBuffer) {
        // 限制处理频率：每帧间隔 ~33ms（≈30fps）
        let now = Date()
        if now.timeIntervalSince(lastFrameAt) < 0.033 { return }
        lastFrameAt = now

        // 把帧处理放到 Task 中异步执行，避免阻塞回调
        frameTask?.cancel()
        frameTask = Task { [weak self] in
            guard let self else { return }
            let frame = await self.poseDetector.detect(pixelBuffer: buffer, orientation: .up)
            await MainActor.run {
                self.applyFrame(frame)
            }
        }
    }

    private func applyFrame(_ frame: PoseFrame?) {
        guard let frame else { return }
        self.lastFrame = frame
        let output = analyzer.process(frame: frame)
        self.repCount = output.repCount
        self.holdSeconds = output.holdSeconds
        self.primaryAngle = output.primaryAngle
        self.stateLabel = output.stateLabel
        self.qualityScore = output.qualityScore
        if output.hasBody {
            lastQualitySum += output.qualityScore
            qualitySamples += 1
        }
        // 反馈：合并显示（最多保留 5 条最近的）
        if !output.newFeedback.isEmpty {
            totalFeedbackCount += output.newFeedback.count
            for f in output.newFeedback {
                recentFeedback.insert(f, at: 0)
                if recentFeedback.count > 5 { recentFeedback.removeLast() }
                if settings.enableVoice || settings.enableHaptics {
                    feedbackService.emit(f)
                }
                bumpIssue(f.title)
            }
        }
    }

    private func bumpIssue(_ title: String) {
        issueCounter[title, default: 0] += 1
        frequentIssues = issueCounter
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map { $0.key }
    }
}