import Foundation
import SwiftData

/// SwiftData 容器持有者，集中管理 ModelContainer。
@MainActor
final class WorkoutStore {

    static let shared = WorkoutStore()

    let container: ModelContainer

    private init() {
        do {
            self.container = try ModelContainer(for: WorkoutSession.self)
        } catch {
            // 持久化失败时回退到内存存储，避免 App 崩溃。
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            // swiftlint:disable:next force_try
            self.container = try! ModelContainer(for: WorkoutSession.self, configurations: config)
        }
    }

    /// 保存一次训练。
    func save(exercise: ExerciseKind,
              startedAt: Date,
              endedAt: Date,
              reps: Int,
              holdSeconds: Double,
              feedbackCount: Int,
              avgQuality: Double) {
        let session = WorkoutSession(exercise: exercise,
                                     startedAt: startedAt,
                                     endedAt: endedAt,
                                     reps: reps,
                                     holdSeconds: holdSeconds,
                                     feedbackCount: feedbackCount,
                                     avgQuality: avgQuality)
        container.mainContext.insert(session)
        try? container.mainContext.save()
    }
}