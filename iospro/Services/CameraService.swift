import AVFoundation
import Foundation
import UIKit

/// 摄像头采集服务：管理 AVCaptureSession，把视频帧以 `CVPixelBuffer` 形式回调出去。
/// 仅做采集与基本朝向处理，不做姿态识别。
final class CameraService: NSObject {

    enum CameraError: LocalizedError {
        case notAuthorized
        case sessionConfiguration
        case noCamera

        var errorDescription: String? {
            switch self {
            case .notAuthorized:        return "未获得摄像头权限"
            case .sessionConfiguration: return "摄像头配置失败"
            case .noCamera:             return "未找到可用摄像头"
            }
        }
    }

    let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "iospro.camera.session")
    private let outputQueue  = DispatchQueue(label: "iospro.camera.output", qos: .userInitiated)
    private var didConfigure = false

    /// 帧回调，主线程外。
    var onPixelBuffer: ((CVPixelBuffer, CMTime) -> Void)?

    /// 申请摄像头权限。
    static func requestAuthorization() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
        default: return false
        }
    }

    /// 配置采集会话（默认前置摄像头，便于用户自拍观察动作）。
    func configureIfNeeded() throws {
        guard !didConfigure else { return }
        didConfigure = true

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .hd1280x720

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
                ?? AVCaptureDevice.default(for: .video) else {
            throw CameraError.noCamera
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) { session.addInput(input) }
        } catch {
            throw CameraError.sessionConfiguration
        }

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        videoOutput.setSampleBufferDelegate(self, queue: outputQueue)
        if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }

        if let connection = videoOutput.connection(with: .video) {
            // 前置摄像头镜像，避免自拍时画面左右颠倒。
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = (device.position == .front)
            }
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
        }
    }

    /// 在后台队列启动会话。
    func start() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.session.isRunning { self.session.startRunning() }
        }
    }

    /// 在后台队列停止会话。
    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning { self.session.stopRunning() }
        }
    }
}

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        onPixelBuffer?(pixelBuffer, pts)
    }
}