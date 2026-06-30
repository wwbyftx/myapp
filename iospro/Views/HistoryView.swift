import SwiftData
import SwiftUI

@MainActor
struct HistoryView: View {
    @State private var viewModel = HistoryViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.sessions.isEmpty {
                    ContentUnavailableView(
                        "还没有训练记录",
                        systemImage: "figure.run",
                        description: Text("完成一次训练后，结果会保存在这里。")
                    )
                } else {
                    List {
                        ForEach(viewModel.sessions) { session in
                            SessionRow(session: session)
                        }
                        .onDelete { indexSet in
                            for i in indexSet { viewModel.delete(viewModel.sessions[i]) }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("历史记录")
            .onAppear { viewModel.refresh() }
            .refreshable { viewModel.refresh() }
        }
    }
}

@MainActor
private struct SessionRow: View {
    let session: WorkoutSession

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: session.exercise.symbolName)
                .font(.title3)
                .foregroundStyle(.orange)
                .frame(width: 40, height: 40)
                .background(Color.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 4) {
                Text(session.exercise.displayName)
                    .font(.headline)
                HStack(spacing: 12) {
                    if session.exercise.isTimed {
                        Label(String(format: "%.1f s", session.holdSeconds), systemImage: "timer")
                    } else {
                        Label("\(session.reps) 次", systemImage: "repeat")
                    }
                    Label("\(Int(session.avgQuality)) 分", systemImage: "star")
                    Label(session.startedAt.formatted(date: .abbreviated, time: .shortened),
                          systemImage: "calendar")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    HistoryView()
        .modelContainer(WorkoutStore.shared.container)
}
