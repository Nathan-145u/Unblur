import Foundation

enum RelativeDateFormatter {
    static func format(_ date: Date, relativeTo now: Date = .now) -> String {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        let startOfDate = calendar.startOfDay(for: date)
        let daysDifference = calendar.dateComponents([.day], from: startOfDate, to: startOfToday).day ?? 0

        if daysDifference == 0 {
            return "Today"
        } else if daysDifference == 1 {
            return "Yesterday"
        } else if daysDifference <= 7 {
            return "\(daysDifference) days ago"
        }

        let dateYear = calendar.component(.year, from: date)
        let currentYear = calendar.component(.year, from: now)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        if dateYear == currentYear {
            formatter.dateFormat = "MMM d"
        } else {
            formatter.dateFormat = "MMM d, yyyy"
        }
        return formatter.string(from: date)
    }
}
