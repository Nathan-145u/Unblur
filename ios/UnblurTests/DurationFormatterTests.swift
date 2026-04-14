import Testing
@testable import Unblur

@Test("Duration 0 shows em dash", arguments: [0])
func durationZero(seconds: Int) {
    #expect(DurationFormatter.format(seconds) == "—")
}

@Test("Duration under 1 hour shows minutes only", arguments: [
    (1, "0m"),
    (59, "0m"),
    (60, "1m"),
    (61, "1m"),
    (719, "11m"),
    (720, "12m"),
    (3540, "59m"),
    (3599, "59m"),
])
func durationMinutesOnly(seconds: Int, expected: String) {
    #expect(DurationFormatter.format(seconds) == expected)
}

@Test("Duration 1 hour or more shows hours and minutes", arguments: [
    (3600, "1h 0m"),
    (3660, "1h 1m"),
    (3900, "1h 5m"),
    (7200, "2h 0m"),
    (7260, "2h 1m"),
    (9000, "2h 30m"),
])
func durationHoursAndMinutes(seconds: Int, expected: String) {
    #expect(DurationFormatter.format(seconds) == expected)
}
