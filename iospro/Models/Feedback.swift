import Foundation

/// 一次动作分析给出的反馈。
struct FormFeedback: Identifiable, Hashable {
    enum Severity: Int, Comparable {
        case info = 0
        case warning = 1
        case error = 2

        static func < (lhs: Severity, rhs: Severity) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    enum Category: String, Hashable {
        case depth
        case tempo
        case alignment
        case rangeOfMotion
        case stability
        case general
    }

    let id = UUID()
    let title: String
    let detail: String?
    let severity: Severity
    let category: Category
    let createdAt: Date

    init(title: String,
         detail: String? = nil,
         severity: Severity = .info,
         category: Category = .general,
         createdAt: Date = .now) {
        self.title = title
        self.detail = detail
        self.severity = severity
        self.category = category
        self.createdAt = createdAt
    }
}