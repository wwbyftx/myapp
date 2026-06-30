import Foundation
import SwiftData

/// 一次完整的训练会话。
@Model
final class WorkoutSession {
    /// 开始时间。
    var startedAt: Date
    /// 结束时间。
    var endedAt: Date
    /// 动作类型原始值。
    var exerciseRaw: String
    /// 完成次数（深蹲/俯卧撑）。
    var reps: Int
    /// 等长动作的保持秒数（平板支撑）。
    var holdSeconds: Double
    /// 训练过程中的有效反馈条数。
    var feedbackCount: Int
    /// 平均动作质量分（0~100）。
    var avgQuality: Double

    init(exercise: ExerciseKind,
         startedAt: Date = .now,
         endedAt: Date = .now,
         reps: Int = 0,
         holdSeconds: Double = 0,
         feedbackCount: Int = 0,
         avgQuality: Double = 0) {
        self.exerciseRaw = exercise.rawValue
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.reps = reps
        self.holdSeconds = holdSeconds
        self.feedbackCount = feedbackCount
        self.avgQuality = avgQuality
    }

    var exercise: ExerciseKind {
        ExerciseKind(rawValue: exerciseRaw) ?? .squat
    }

    var duration: TimeInterval { endedAt.timeIntervalSince(startedAt) }
}