import Foundation
import Vision

/// 支持的健身动作类型。
enum ExerciseKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case squat
    case pushup
    case plank

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .squat:  return "深蹲"
        case .pushup:  return "俯卧撑"
        case .plank:   return "平板支撑"
        }
    }

    var symbolName: String {
        switch self {
        case .squat:  return "figure.strengthtraining.functional"
        case .pushup:  return "figure.strengthtraining.traditional"
        case .plank:   return "figure.core.training"
        }
    }

    var summary: String {
        switch self {
        case .squat:  return "下肢与核心的基础复合动作"
        case .pushup:  return "强化胸、肩、肱三头与核心稳定"
        case .plank:   return "等长收缩，锻炼核心抗伸展能力"
        }
    }

    /// 是否为等长收缩类动作（无次数，按时间计）。
    var isTimed: Bool { self == .plank }
}