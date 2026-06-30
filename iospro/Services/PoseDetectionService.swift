import Foundation
import Vision

/// 姿态识别服务：把视频帧转换为 `PoseFrame`。
/// 优先使用 3D 姿态（iOS 17+），否则回退到 2D 姿态。
final class PoseDetectionService {

    enum DetectionError: Error {
        case noObservation
    }

    private let sequenceHandler = VNSequenceRequestHandler()
    private let visionQueue = DispatchQueue(label: "iospro.vision", qos: .userInitiated)

    /// 是否启用 3D 检测。
    var prefer3D: Bool = true

    /// 检测一帧；返回的回调在后台线程。
    func detect(pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation = .up) async -> PoseFrame? {
        await withCheckedContinuation { (continuation: CheckedContinuation<PoseFrame?, Never>) in
            visionQueue.async { [weak self] in
                guard let self else { continuation.resume(returning: nil); return }
                let result = self.detectSync(pixelBuffer: pixelBuffer, orientation: orientation)
                continuation.resume(returning: result)
            }
        }
    }

    private func detectSync(pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) -> PoseFrame? {
        let timestamp = CACurrentMediaTime()

        if prefer3D, #available(iOS 17.0, *) {
            if let frame = detect3DSync(pixelBuffer: pixelBuffer, orientation: orientation, timestamp: timestamp) {
                return frame
            }
        }
        return detect2DSync(pixelBuffer: pixelBuffer, orientation: orientation, timestamp: timestamp)
    }

    @available(iOS 17.0, *)
    private func detect3DSync(pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation, timestamp: TimeInterval) -> PoseFrame? {
        let request = VNDetectHumanBodyPose3DRequest()
        do {
            try sequenceHandler.perform([request], on: pixelBuffer, orientation: orientation)
        } catch {
            return nil
        }
        guard let observation = request.results?.first as? VNHumanBodyPose3DObservation else { return nil }
        return frameFrom3D(observation, timestamp: timestamp)
    }

    @available(iOS 17.0, *)
    private func frameFrom3D(_ obs: VNHumanBodyPose3DObservation, timestamp: TimeInterval) -> PoseFrame {
        var joints: [BodyJoint: JointPoint] = [:]
        for joint in BodyJoint.allCases {
            let p = obs.localizedPoint(for: joint.visionName, in: 0)
            // 仅在关节有效时填入。
            if p.x.isFinite, p.y.isFinite, p.z.isFinite,
               abs(p.x) + abs(p.y) + abs(p.z) > 0.0001 {
                joints[joint] = JointPoint(position: SIMD3<Float>(Float(p.x), Float(p.y), Float(p.z)),
                                          confidence: 1.0)
            }
        }
        return PoseFrame(timestamp: timestamp, joints: joints, is3D: true)
    }

    private func detect2DSync(pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation, timestamp: TimeInterval) -> PoseFrame? {
        let request = VNDetectHumanBodyPoseRequest()
        do {
            try sequenceHandler.perform([request], on: pixelBuffer, orientation: orientation)
        } catch {
            return nil
        }
        guard let observation = request.results?.first as? VNHumanBodyPoseObservation else { return nil }
        return frameFrom2D(observation, timestamp: timestamp)
    }

    private func frameFrom2D(_ obs: VNHumanBodyPoseObservation, timestamp: TimeInterval) -> PoseFrame {
        var joints: [BodyJoint: JointPoint] = [:]
        let recognizedPoints = (try? obs.recognizedPoints(.all)) ?? [:]
        for (key, point) in recognizedPoints {
            guard point.confidence > 0.2 else { continue }
            let joint = BodyJoint(key)
            joints[joint] = JointPoint(position: SIMD3<Float>(Float(point.location.x),
                                                              Float(point.location.y),
                                                              0),
                                       confidence: point.confidence)
        }
        return PoseFrame(timestamp: timestamp, joints: joints, is3D: false)
    }
}