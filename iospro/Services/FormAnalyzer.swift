import Foundation

/// 一次分析的结果：用于驱动 UI 与反馈。
struct AnalyzerOutput {
    /// 完成次数（仅对计数类动作有效）。
    var repCount: Int
    /// 当前主要可显示角度（度数）。
    var primaryAngle: Float?
    /// 当前的运动状态描述。
    var stateLabel: String
    /// 0~100 的质量分（用于汇总平均）。
    var qualityScore: Double
    /// 本帧新增的反馈（已经在历史窗口中做去重抑制）。
    var newFeedback: [FormFeedback]
    /// 等长动作的累计有效保持秒数。
    var holdSeconds: Double
    /// 是否有完整的人体姿态（否则不计次数）。
    var hasBody: Bool
}

/// 动作分析器：把每帧 `PoseFrame` 转成反馈 + 计数。
/// 使用规则化算法：基于关节角度与身体线对齐，输出可解释的纠错建议。
/// 完全在设备端运行、零延迟、零费用。
final class FormAnalyzer {

    private let exercise: ExerciseKind
    private var lastFeedbackAt: [String: Date] = [:]
    private let feedbackCooldown: TimeInterval = 2.5

    // 计数状态机
    private enum Phase { case up, descending, bottom, ascending }
    private var phase: Phase = .up
    private var repCount: Int = 0

    // 等长动作计时
    private var holdStart: Date?
    private var holdSeconds: Double = 0
    private var goodHoldAccumulator: TimeInterval = 0
    private var lastTick: Date = .now

    // 质量分（指数移动平均）
    private var qualityEMA: Double = 80

    init(exercise: ExerciseKind) {
        self.exercise = exercise
    }

    func process(frame: PoseFrame) -> AnalyzerOutput {
        switch exercise {
        case .squat:  return analyzeSquat(frame)
        case .pushup: return analyzePushup(frame)
        case .plank:  return analyzePlank(frame)
        }
    }

    // MARK: - 深蹲

    private func analyzeSquat(_ frame: PoseFrame) -> AnalyzerOutput {
        let required: [BodyJoint] = [.rightHip, .rightKnee, .rightAnkle,
                                     .leftHip,  .leftKnee,  .leftAnkle,
                                     .rightShoulder, .leftShoulder]
        guard hasAll(frame, required),
              let kneeAngle = averageAngle(frame,
                                           a: [.rightHip, .leftHip],
                                           b: [.rightKnee, .leftKnee],
                                           c: [.rightAnkle, .leftAnkle]),
              let hipAngle = averageAngle(frame,
                                          a: [.rightShoulder, .leftShoulder],
                                          b: [.rightHip, .leftHip],
                                          c: [.rightKnee, .leftKnee]) else {
            return empty()
        }

        var feedback: [FormFeedback] = []
        var quality: Double = 100

        if kneeAngle < 90 {
            if let f = emit("squat.depth", severity: .info, title: "深度很棒", detail: "髋关节低于膝关节，标准全蹲。") {
                feedback.append(f)
            }
        } else if kneeAngle > 140 && phase != .up {
            if let f = emit("squat.depth", severity: .warning,
                            title: "下蹲深度不足",
                            detail: "试着让髋部降到与膝盖同高或更低。") {
                feedback.append(f)
            }
            quality -= 10
        }

        if hipAngle < 60 {
            if let f = emit("squat.back", severity: .error,
                            title: "上身过度前倾",
                            detail: "保持胸口抬起，视线平视前方，减少腰椎压力。") {
                feedback.append(f)
            }
            quality -= 20
        } else if hipAngle < 75 {
            if let f = emit("squat.back", severity: .warning,
                            title: "上身略前倾",
                            detail: "收紧核心，胸口朝向正前方。") {
                feedback.append(f)
            }
            quality -= 8
        }

        updateRepPhase(angle: kneeAngle, downThreshold: 110, upThreshold: 165)
        quality = clamp(quality, 0, 100)
        qualityEMA = 0.7 * qualityEMA + 0.3 * quality

        return AnalyzerOutput(repCount: repCount,
                              primaryAngle: kneeAngle,
                              stateLabel: stateLabel(),
                              qualityScore: qualityEMA,
                              newFeedback: feedback,
                              holdSeconds: 0,
                              hasBody: true)
    }

    // MARK: - 俯卧撑

    private func analyzePushup(_ frame: PoseFrame) -> AnalyzerOutput {
        let required: [BodyJoint] = [.rightShoulder, .rightElbow, .rightWrist,
                                     .leftShoulder,  .leftElbow,  .leftWrist,
                                     .rightHip,      .rightKnee,  .rightAnkle,
                                     .leftHip,       .leftKnee,   .leftAnkle]
        guard hasAll(frame, required),
              let elbowAngle = averageAngle(frame,
                                            a: [.rightShoulder, .leftShoulder],
                                            b: [.rightElbow, .leftElbow],
                                            c: [.rightWrist, .leftWrist]),
              let bodyLine = averageAngle(frame,
                                          a: [.rightShoulder, .leftShoulder],
                                          b: [.rightHip, .leftHip],
                                          c: [.rightKnee, .leftKnee]) else {
            return empty()
        }

        var feedback: [FormFeedback] = []
        var quality: Double = 100

        if bodyLine < 160 {
            if let f = emit("pushup.line", severity: .error,
                            title: "身体未成直线",
                            detail: "收紧核心，臀部与肩部同高，不要塌腰或撅臀。") {
                feedback.append(f)
            }
            quality -= 20
        } else if bodyLine < 170 {
            if let f = emit("pushup.line", severity: .warning,
                            title: "躯干轻微弯曲",
                            detail: "想象身体从肩到踝是一块平板。") {
                feedback.append(f)
            }
            quality -= 6
        }

        if elbowAngle < 90 {
            if let f = emit("pushup.depth", severity: .info, title: "下放到位", detail: "肘部夹角小于 90°。") {
                feedback.append(f)
            }
        } else if elbowAngle > 140 && phase != .up {
            if let f = emit("pushup.depth", severity: .warning,
                            title: "下降幅度不足",
                            detail: "让胸部更接近地面，但不要耸肩。") {
                feedback.append(f)
            }
            quality -= 10
        }

        updateRepPhase(angle: elbowAngle, downThreshold: 110, upThreshold: 165)
        quality = clamp(quality, 0, 100)
        qualityEMA = 0.7 * qualityEMA + 0.3 * quality

        return AnalyzerOutput(repCount: repCount,
                              primaryAngle: elbowAngle,
                              stateLabel: stateLabel(),
                              qualityScore: qualityEMA,
                              newFeedback: feedback,
                              holdSeconds: 0,
                              hasBody: true)
    }

    // MARK: - 平板支撑

    private func analyzePlank(_ frame: PoseFrame) -> AnalyzerOutput {
        let required: [BodyJoint] = [.rightShoulder, .rightElbow, .rightWrist,
                                     .leftShoulder,  .leftElbow,  .leftWrist,
                                     .rightHip,      .rightKnee,  .rightAnkle,
                                     .leftHip,       .leftKnee,   .leftAnkle]
        guard hasAll(frame, required),
              let bodyLine = averageAngle(frame,
                                          a: [.rightShoulder, .leftShoulder],
                                          b: [.rightHip, .leftHip],
                                          c: [.rightKnee, .leftKnee]) else {
            return empty()
        }

        var feedback: [FormFeedback] = []
        var quality: Double = 100
        let isGood = bodyLine >= 170 && bodyLine <= 185

        if !isGood {
            if bodyLine < 165 {
                if let f = emit("plank.hip", severity: .error,
                                title: "髋部塌陷",
                                detail: "把髋部抬起来，与肩、膝成一条直线。") {
                    feedback.append(f)
                }
                quality -= 25
            } else if bodyLine > 195 {
                if let f = emit("plank.hip", severity: .error,
                                title: "髋部过高",
                                detail: "降低髋部，让肩膀、髋、踝对齐。") {
                    feedback.append(f)
                }
                quality -= 25
            } else if bodyLine < 170 {
                if let f = emit("plank.hip", severity: .warning,
                                title: "躯干略下垂",
                                detail: "再收紧一点核心。") {
                    feedback.append(f)
                }
                quality -= 10
            } else if bodyLine > 185 {
                if let f = emit("plank.hip", severity: .warning,
                                title: "躯干略拱起",
                                detail: "下沉髋部。") {
                    feedback.append(f)
                }
                quality -= 10
            }
        }

        let now = Date()
        let dt = now.timeIntervalSince(lastTick)
        lastTick = now
        if isGood {
            if holdStart == nil { holdStart = now }
            goodHoldAccumulator += dt
            if let f = emit("plank.ongoing", severity: .info,
                            title: "保持住",
                            detail: String(format: "已坚持 %.1f 秒", holdSeconds + goodHoldAccumulator)) {
                feedback.append(f)
            }
        } else {
            if goodHoldAccumulator > 0 {
                holdSeconds += goodHoldAccumulator
                goodHoldAccumulator = 0
            }
            holdStart = nil
        }

        quality = clamp(quality, 0, 100)
        qualityEMA = 0.9 * qualityEMA + 0.1 * quality

        return AnalyzerOutput(repCount: 0,
                              primaryAngle: bodyLine,
                              stateLabel: isGood ? "保持中" : "调整姿态",
                              qualityScore: qualityEMA,
                              newFeedback: feedback,
                              holdSeconds: holdSeconds + goodHoldAccumulator,
                              hasBody: true)
    }

    // MARK: - 状态机与辅助

    private func updateRepPhase(angle: Float, downThreshold: Float, upThreshold: Float) {
        switch phase {
        case .up:
            if angle < upThreshold { phase = .descending }
        case .descending:
            if angle < downThreshold { phase = .bottom }
            else if angle > upThreshold { phase = .up } // 半途放弃
        case .bottom:
            if angle > downThreshold { phase = .ascending }
        case .ascending:
            if angle > upThreshold {
                repCount += 1
                phase = .up
            } else if angle < downThreshold {
                phase = .bottom // 二次下蹲
            }
        }
    }

    private func empty() -> AnalyzerOutput {
        AnalyzerOutput(repCount: repCount,
                       primaryAngle: nil,
                       stateLabel: "未识别到完整人体",
                       qualityScore: qualityEMA,
                       newFeedback: [],
                       holdSeconds: holdSeconds + goodHoldAccumulator,
                       hasBody: false)
    }

    private func stateLabel() -> String {
        switch phase {
        case .up:         return "站立 / 准备"
        case .descending: return "下放中"
        case .bottom:     return "到位"
        case .ascending:  return "上升中"
        }
    }

    private func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double {
        min(max(v, lo), hi)
    }

    private func hasAll(_ frame: PoseFrame, _ joints: [BodyJoint]) -> Bool {
        for j in joints where frame.point(j) == nil { return false }
        return true
    }

    /// 左右两侧同名关节角度均值（度数）。
    private func averageAngle(_ frame: PoseFrame,
                              a: [BodyJoint], b: [BodyJoint], c: [BodyJoint]) -> Float? {
        var sum: Float = 0
        var count: Int = 0
        for i in 0..<min(a.count, b.count, c.count) {
            if let v = frame.angleDegrees(a[i], b[i], c[i]) {
                sum += v
                count += 1
            }
        }
        guard count > 0 else { return nil }
        return sum / Float(count)
    }

    /// 带冷却的反馈发射：相同 key 在冷却时间内只返回 nil。
    private func emit(_ key: String,
                      severity: FormFeedback.Severity,
                      title: String,
                      detail: String?) -> FormFeedback? {
        let now = Date()
        if let last = lastFeedbackAt[key], now.timeIntervalSince(last) < feedbackCooldown {
            return nil
        }
        lastFeedbackAt[key] = now
        return FormFeedback(title: title, detail: detail, severity: severity)
    }
}