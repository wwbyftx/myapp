import SwiftUI

/// 顶部或底部的反馈条。
@MainActor
struct FeedbackBannerView: View {
    let feedback: FormFeedback

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .font(.title3)
                .foregroundStyle(iconColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(feedback.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                if let detail = feedback.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(2)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(background, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(iconColor.opacity(0.4), lineWidth: 1)
        )
    }

    private var iconName: String {
        switch feedback.severity {
        case .error:   return "exclamationmark.triangle.fill"
        case .warning: return "exclamationmark.circle.fill"
        case .info:    return "checkmark.circle.fill"
        }
    }

    private var iconColor: Color {
        switch feedback.severity {
        case .error:   return .red
        case .warning: return .yellow
        case .info:    return .green
        }
    }

    private var background: Color {
        Color.white.opacity(0.08)
    }
}
