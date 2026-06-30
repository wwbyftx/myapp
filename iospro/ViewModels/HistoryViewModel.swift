import Foundation
import SwiftData

/// 历史页面的 ViewModel。
@MainActor
@Observable
final class HistoryViewModel {

    var sessions: [WorkoutSession] = []

    func refresh() {
        let context = WorkoutStore.shared.container.mainContext
        let descriptor = FetchDescriptor<WorkoutSession>(
            sortBy: [SortDescriptor(\.endedAt, order: .reverse)]
        )
        sessions = (try? context.fetch(descriptor)) ?? []
    }

    func delete(_ session: WorkoutSession) {
        WorkoutStore.shared.container.mainContext.delete(session)
        try? WorkoutStore.shared.container.mainContext.save()
        refresh()
    }
}