import Foundation

struct LabCheckSuggestion {
    enum Reason {
        case noReport
        case recentAbnormal
        case earlyHRT
        case stable
    }

    let intervalWeeks: Int
    let nextDate: Date
    let anchorDate: Date
    let reason: Reason
}

struct LabCheckAdvisor {
    static func suggest(
        hrtStartDate: Date,
        latestReport: LabReport?,
        fallbackLastCheckDate: Date,
        today: Date = .now
    ) -> LabCheckSuggestion {
        let startDate = Calendar.current.startOfDay(for: hrtStartDate)
        let todayStart = Calendar.current.startOfDay(for: today)
        let daysSinceStart = max(0, Calendar.current.dateComponents([.day], from: startDate, to: todayStart).day ?? 0)

        let baseIntervalWeeks: Int
        if daysSinceStart < 90 {
            baseIntervalWeeks = 4
        } else if daysSinceStart < 180 {
            baseIntervalWeeks = 6
        } else if daysSinceStart < 365 {
            baseIntervalWeeks = 8
        } else {
            baseIntervalWeeks = 12
        }

        let anchorDate = latestReport?.date ?? fallbackLastCheckDate

        if let latestReport {
            let isAbnormal = latestReport.interpretation != .normal || latestReport.suggestion != .noAdjustment
            if isAbnormal {
                let intervalWeeks = min(baseIntervalWeeks, 4)
                let nextDate = Calendar.current.date(byAdding: .day, value: intervalWeeks * 7, to: anchorDate) ?? anchorDate
                return LabCheckSuggestion(intervalWeeks: intervalWeeks, nextDate: nextDate, anchorDate: anchorDate, reason: .recentAbnormal)
            }
        } else {
            let intervalWeeks = min(baseIntervalWeeks, 4)
            let nextDate = Calendar.current.date(byAdding: .day, value: intervalWeeks * 7, to: anchorDate) ?? anchorDate
            return LabCheckSuggestion(intervalWeeks: intervalWeeks, nextDate: nextDate, anchorDate: anchorDate, reason: .noReport)
        }

        let reason: LabCheckSuggestion.Reason = daysSinceStart < 180 ? .earlyHRT : .stable
        let nextDate = Calendar.current.date(byAdding: .day, value: baseIntervalWeeks * 7, to: anchorDate) ?? anchorDate
        return LabCheckSuggestion(intervalWeeks: baseIntervalWeeks, nextDate: nextDate, anchorDate: anchorDate, reason: reason)
    }
}
