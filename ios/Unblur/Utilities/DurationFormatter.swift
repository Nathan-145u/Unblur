enum DurationFormatter {
    static func format(_ seconds: Int) -> String {
        guard seconds > 0 else { return "—" }

        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if hours >= 1 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
