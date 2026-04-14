import Foundation
import Testing
@testable import Unblur

@Test("Today shows 'Today'")
func today() {
    let now = Date()
    #expect(RelativeDateFormatter.format(now) == "Today")
}

@Test("Yesterday shows 'Yesterday'")
func yesterday() {
    let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
    #expect(RelativeDateFormatter.format(yesterday) == "Yesterday")
}

@Test("2-6 days ago shows 'X days ago'")
func daysAgo() {
    for days in 2...6 {
        let date = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        #expect(RelativeDateFormatter.format(date) == "\(days) days ago")
    }
}

@Test("7 days ago shows 'X days ago'")
func sevenDaysAgo() {
    let date = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
    #expect(RelativeDateFormatter.format(date) == "7 days ago")
}

@Test("This year shows short month and day")
func thisYear() {
    let calendar = Calendar.current
    let now = Date()
    // Use a date 30 days ago (likely this year and > 7 days ago)
    guard let date = calendar.date(byAdding: .day, value: -30, to: now) else { return }
    let year = calendar.component(.year, from: date)
    let currentYear = calendar.component(.year, from: now)

    // Only test if the date is still in the current year
    if year == currentYear {
        let result = RelativeDateFormatter.format(date)
        // Should match pattern like "Mar 15"
        #expect(!result.contains(","))
        #expect(!result.contains("ago"))
        #expect(!result.contains("Today"))
    }
}

@Test("Previous year shows month, day, and year")
func previousYear() {
    let calendar = Calendar.current
    // Use Jan 15 of last year
    let currentYear = calendar.component(.year, from: Date())
    let components = DateComponents(year: currentYear - 1, month: 3, day: 15)
    let date = calendar.date(from: components)!

    let result = RelativeDateFormatter.format(date)
    #expect(result.contains(","))
    #expect(result.contains("\(currentYear - 1)"))
}
