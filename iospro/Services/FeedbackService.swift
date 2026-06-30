import AVFoundation
import CoreHaptics
import Foundation
import UIKit

/// 反馈输出：语音 + 触觉 + 系统通知。
/// 语音由系统 TTS 完成；触觉在支持的设备上提供差异化提示。
@MainActor
final class FeedbackService {

    private let synthesizer = AVSpeechSynthesizer()
    private var lastSpokenAt: [String: Date] = [:]
    private let speechCooldown: TimeInterval = 3.0

    private var hapticEngine: CHHapticEngine?
    private let supportsHaptics: Bool

    init() {
        supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
        if supportsHaptics {
            do {
                let engine = try CHHapticEngine()
                engine.resetHandler = { [weak self] in
                    try? self?.hapticEngine?.start()
                }
                engine.stoppedHandler = { _ in }
                try engine.start()
                self.hapticEngine = engine
            } catch {
                self.hapticEngine = nil
            }
        }
    }

    /// 根据反馈等级给出对应的语音 + 触觉提示。
    func emit(_ feedback: FormFeedback) {
        // 触觉
        if supportsHaptics {
            playHaptic(for: feedback.severity)
        } else {
            let style: UIImpactFeedbackGenerator.FeedbackStyle =
                feedback.severity == .error ? .heavy :
                (feedback.severity == .warning ? .medium : .light)
            UIImpactFeedbackGenerator(style: style).impactOccurred()
        }

        // 语音：相同 key 冷却，避免唠叨
        let key = feedback.title
        let now = Date()
        if let last = lastSpokenAt[key], now.timeIntervalSince(last) < speechCooldown { return }
        lastSpokenAt[key] = now

        let utterance = AVSpeechUtterance(string: feedback.title)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.volume = 0.9
        if feedback.severity == .error { utterance.pitchMultiplier = 1.05 }
        if feedback.severity == .info  { utterance.pitchMultiplier = 0.95 }
        synthesizer.speak(utterance)
    }

    /// 庆祝：完成一组动作时调用。
    func celebrate() {
        let utterance = AVSpeechUtterance(string: "好棒！再来一组！")
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.pitchMultiplier = 1.1
        synthesizer.speak(utterance)

        if supportsHaptics {
            do {
                let event = CHHapticEvent(eventType: .hapticContinuous,
                                          parameters: [
                                            CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
                                          ],
                                          relativeTime: 0,
                                          duration: 0.4)
                let pattern = try CHHapticPattern(events: [event], parameters: [])
                let player = try hapticEngine?.makePlayer(with: pattern)
                try player?.start(atTime: 0)
            } catch {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    private func playHaptic(for severity: FormFeedback.Severity) {
        guard let engine = hapticEngine else { return }
        let intensity: Float
        let sharpness: Float
        switch severity {
        case .error:   intensity = 1.0; sharpness = 0.8
        case .warning: intensity = 0.7; sharpness = 0.5
        case .info:    intensity = 0.4; sharpness = 0.3
        }
        do {
            let event = CHHapticEvent(eventType: .hapticTransient,
                                      parameters: [
                                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                                        CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
                                      ],
                                      relativeTime: 0)
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            // 静默失败
        }
    }
}