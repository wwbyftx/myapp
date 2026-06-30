import SwiftUI

@MainActor
struct HomeView: View {
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    quickStartCard
                    exercisesSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color.black.opacity(0.95).ignoresSafeArea())
            .navigationTitle("AI 健身教练")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: ExerciseKind.self) { kind in
                CameraWorkoutView(exercise: kind)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("用摄像头，实时纠正每一个动作")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
            Text("无需穿戴设备。基于 Apple Vision 的人体姿态识别，结合规则化算法与可选的 AI 教练建议，给你即时的语音、触觉与画面反馈。")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private var quickStartCard: some View {
        Button {
            path.append(ExerciseKind.squat)
        } label: {
            HStack(spacing: 16) {
                Image(systemName: "bolt.fill")
                    .font(.title)
                    .foregroundStyle(.black)
                    .frame(width: 48, height: 48)
                    .background(Color.orange, in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text("快速开始")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("推荐动作：深蹲")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(16)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选择动作")
                .font(.headline)
                .foregroundStyle(.white)
            VStack(spacing: 12) {
                ForEach(ExerciseKind.allCases) { kind in
                    NavigationLink(value: kind) {
                        ExerciseRow(exercise: kind)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

@MainActor
private struct ExerciseRow: View {
    let exercise: ExerciseKind
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: exercise.symbolName)
                .font(.title2)
                .foregroundStyle(.orange)
                .frame(width: 44, height: 44)
                .background(Color.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.displayName)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(exercise.summary)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(14)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    HomeView()
        .environment(AppSettings.shared)
}
