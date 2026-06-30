import SwiftUI

@MainActor
struct CameraWorkoutView: View {
    let exercise: ExerciseKind
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: WorkoutViewModel
    @State private var showSummary = false
    @State private var showPermissionAlert = false

    init(exercise: ExerciseKind) {
        self.exercise = exercise
        self._viewModel = State(initialValue: WorkoutViewModel(exercise: exercise))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // 摄像头预览
            CameraPreview(session: viewModel.camera.session)
                .ignoresSafeArea()

            // 姿态叠加
            GeometryReader { proxy in
                PoseOverlayView(frame: viewModel.lastFrame, boundsSize: proxy.size)
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                Spacer()
                if let feedback = viewModel.recentFeedback.first {
                    FeedbackBannerView(feedback: feedback)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                statsPanel
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.recentFeedback.first?.id)
        .task {
            await viewModel.start()
            if viewModel.permissionDenied {
                showPermissionAlert = true
            }
        }
        .onDisappear {
            // 退出页面时如果还没保存，自动保存一次（幂等）。
            viewModel.stopAndSave()
        }
        .alert("需要摄像头权限", isPresented: $showPermissionAlert) {
            Button("去设置") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
                dismiss()
            }
            Button("取消", role: .cancel) { dismiss() }
        } message: {
            Text("请在系统设置中允许本 App 使用摄像头，以便分析你的动作。")
        }
        .sheet(isPresented: $showSummary, onDismiss: { dismiss() }) {
            WorkoutSummarySheet(viewModel: viewModel)
        }
    }

    // MARK: - 子视图

    private var topBar: some View {
        HStack {
            Button {
                // 直接退出�停止采集，onDisappear 会保存。Summary 不弹。
                viewModel.camera.stop()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
            }
            Spacer()
            VStack(spacing: 2) {
                Text(exercise.displayName)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(viewModel.stateLabel)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            Spacer()
            Button {
                Task { await viewModel.requestAIAdvice() }
            } label: {
                Image(systemName: "sparkles")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .opacity(viewModel.lastError == nil ? 1 : 0.4)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var statsPanel: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                StatTile(title: exercise.isTimed ? "保持秒数" : "次数",
                         value: exercise.isTimed
                            ? String(format: "%.1f", viewModel.holdSeconds)
                            : "\(viewModel.repCount)",
                         systemImage: exercise.isTimed ? "timer" : "repeat")
                StatTile(title: "主要角度",
                         value: viewModel.primaryAngle.map { String(format: "%.0f°", $0) } ?? "--",
                         systemImage: "angle")
                StatTile(title: "质量分",
                         value: "\(Int(viewModel.qualityScore))",
                         systemImage: "star.fill")
            }
            Button {
                // 结束训��：保存 + 弹总结
                viewModel.stopAndSave()
                showSummary = true
            } label: {
                Label("结束训练", systemImage: "stop.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.orange, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.black)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .padding(.top, 12)
        .background(
            LinearGradient(colors: [.black.opacity(0), .black.opacity(0.6)],
                           startPoint: .top, endPoint: .bottom)
        )
    }
}

@MainActor
private struct StatTile: View {
    let title: String
    let value: String
    let systemImage: String
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundStyle(.orange)
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .monospacedDigit()
            Text(title)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

@MainActor
private struct WorkoutSummarySheet: View {
    @Bindable var viewModel: WorkoutViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    summaryHeader

                    if let advice = viewModel.aiAdvice {
                        adviceCard(advice)
                    } else if viewModel.loadingAI {
                        HStack {
                            ProgressView()
                            Text("AI 教练正在分析…")
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    } else if let err = viewModel.lastError {
                        Text("AI 建议不可用：\(err)")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    } else {
                        Button {
                            Task { await viewModel.requestAIAdvice() }
                        } label: {
                            Label("获取 AI 教练建议", systemImage: "sparkles")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(20)
            }
            .navigationTitle("训练完成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private var summaryHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.exercise.displayName)
                .font(.title2.weight(.bold))
            HStack(spacing: 16) {
                if viewModel.exercise.isTimed {
                    SummaryStat(title: "保持", value: String(format: "%.1f s", viewModel.holdSeconds))
                } else {
                    SummaryStat(title: "次数", value: "\(viewModel.repCount)")
                }
                SummaryStat(title: "质量分", value: "\(Int(viewModel.qualityScore))")
                SummaryStat(title: "反馈", value: "\(viewModel.totalFeedbackCount)")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
    }

    private func adviceCard(_ advice: AIService.Advice) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.orange)
                Text(advice.headline)
                    .font(.headline)
            }
            ForEach(advice.suggestions, id: \.self) { s in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                        .foregroundStyle(.orange)
                        .padding(.top, 7)
                    Text(s)
                        .font(.subheadline)
                }
            }
            Divider()
            Text(advice.encouragement)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
    }
}

@MainActor
private struct SummaryStat: View {
    let title: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
