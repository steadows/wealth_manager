import Foundation

nonisolated enum TimePeriod: Sendable {
    case week
    case month
    case quarter
    case year
    case custom(ClosedRange<Date>)

    /// Returns the date range ending at (or containing) the given date.
    func dateRange(from date: Date) -> ClosedRange<Date> {
        let calendar = Calendar.current

        switch self {
        case .week:
            let start = calendar.date(byAdding: .weekOfYear, value: -1, to: date)!
            return start...date

        case .month:
            let start = calendar.date(byAdding: .month, value: -1, to: date)!
            return start...date

        case .quarter:
            let start = calendar.date(byAdding: .month, value: -3, to: date)!
            return start...date

        case .year:
            let start = calendar.date(byAdding: .year, value: -1, to: date)!
            return start...date

        case .custom(let range):
            return range
        }
    }
}
