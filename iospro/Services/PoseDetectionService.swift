import Foundation
import QuartzCore
import Vision

/// 姿态识别服务：把视频帧转换为 `PoseFrame`。
/// 使用 Apple Vision 2D 人体姿态识别，完全在设备端运行，零延迟。
final class PoseDetectionService {

    enum DetectionError: Error {
        case noObservation
    }

    private let sequenceHandler = VNSequenceRequestHandler()
    private let visionQueue = DispatchQueue(label: "iospro.vision", qos: .userInitiated)

    /// 检测一帧；返回的回调在后台线程。
    func detect(pixelBuffer: CVPixelBuffer,
                orientation: CGImagePropertyOrientation = .up) async -> PoseFrame? {
        await withCheckedContinuation { (continuation: CheckedContinuation<PoseFrame?, Never>) in
            visionQueue.async { [weak self] in
                guard let self else { continuation.resume(returning: nil); return }
                let result = self.detectSync(pixelBuffer: pixelBuffer, orientation: orientation)
                continuation.resume(returning: result)
            }
        }
    }

    private func detectSync(pixelBuffer: CVPixelBuffer,
                            orientation: CGImagePropertyOrientation) -> PoseFrame? {
        let timestamp = CACurrentMediaTime()
        let request = VNDetectHumanBodyPoseRequest()
        do {
            try sequenceHandler.perform([request], on: pixelBuffer, orientation: orientation)
        } catch {
            return nil
        }
        guard let observation = request.results?.first as? VNHumanBodyPoseObservation else {
            return nil
        }
        return frameFrom2D(observation, timestamp: timestamp)
    }

    private func frameFrom2D(_ obs: VNHumanBodyPoseObservation, timestamp: TimeInterval) -> PoseFrame {
        var joints: [BodyJoint: JointPoint] = [:]
        let recognizedPoints = (try? obs.recognizedPoints(.all)) ?? [:]
        for (key, point) in recognizedPoints {
            guard point.confidence > 0.2 else { continue }
            let joint = BodyJoint(key)
            let px = Float(point.location.x)
            let py = Float(point.location.y)
            let position = SIMD3<Float>(px, py, 0)
            joints[joint] = JointPoint(position: position, confidence: point.confidence)
        }
        return PoseFrame(timestamp: timestamp, joints: joints, is3D: false)
    }
}