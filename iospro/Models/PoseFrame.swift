import Foundation
import Vision
import simd

/// 简化的关节名，内部使用，避免业务层直接耦合 Vision 枚举。
enum BodyJoint: String, Codable, CaseIterable, Hashable {
    case nose
    case neck
    case rightShoulder, rightElbow, rightWrist
    case leftShoulder,  leftElbow,  leftWrist
    case root
    case rightHip, rightKnee, rightAnkle
    case leftHip,  leftKnee,  leftAnkle

    init(_ name: VNHumanBodyPoseObservation.JointName) {
        switch name {
        case .nose: self = .nose
        case .neck: self = .neck
        case .rightShoulder: self = .rightShoulder
        case .rightElbow: self = .rightElbow
        case .rightWrist: self = .rightWrist
        case .leftShoulder: self = .leftShoulder
        case .leftElbow: self = .leftElbow
        case .leftWrist: self = .leftWrist
        case .root: self = .root
        case .rightHip: self = .rightHip
        case .rightKnee: self = .rightKnee
        case .rightAnkle: self = .rightAnkle
        case .leftHip: self = .leftHip
        case .leftKnee: self = .leftKnee
        case .leftAnkle: self = .leftAnkle
        @unknown default: self = .root
        }
    }

    var visionName: VNHumanBodyPoseObservation.JointName {
        switch self {
        case .nose:            return .nose
        case .neck:            return .neck
        case .rightShoulder:   return .rightShoulder
        case .rightElbow:      return .rightElbow
        case .rightWrist:      return .rightWrist
        case .leftShoulder:    return .leftShoulder
        case .leftElbow:       return .leftElbow
        case .leftWrist:       return .leftWrist
        case .root:            return .root
        case .rightHip:        return .rightHip
        case .rightKnee:       return .rightKnee
        case .rightAnkle:      return .rightAnkle
        case .leftHip:         return .leftHip
        case .leftKnee:        return .leftKnee
        case .leftAnkle:       return .leftAnkle
        }
    }
}

/// 单个关节点的三维位置与置信度。2D 模式下 z = 0。
struct JointPoint: Hashable {
    var position: SIMD3<Float>
    var confidence: Float
}

/// 一帧姿态数据。
struct PoseFrame: Hashable {
    let timestamp: TimeInterval
    let joints: [BodyJoint: JointPoint]
    let is3D: Bool

    func point(_ joint: BodyJoint) -> JointPoint? {
        joints[joint]
    }

    /// 计算三点 a-b-c 的角度（顶点为 b），单位弧度。
    static func angle(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>) -> Float {
        let ba = a - b
        let bc = c - b
        let n1 = simd_length(ba)
        let n2 = simd_length(bc)
        guard n1 > 1e-5, n2 > 1e-5 else { return .nan }
        let cos = simd_dot(ba, bc) / (n1 * n2)
        return acos(max(-1, min(1, cos)))
    }

    /// 计算三点角度（顶点为 b），返回度数；任一点缺失返回 nil。
    func angleDegrees(_ a: BodyJoint, _ b: BodyJoint, _ c: BodyJoint) -> Float? {
        guard let pa = point(a)?.position,
              let pb = point(b)?.position,
              let pc = point(c)?.position else { return nil }
        let rad = Self.angle(pa, pb, pc)
        return rad.isNaN ? nil : rad * 180 / .pi
    }
}