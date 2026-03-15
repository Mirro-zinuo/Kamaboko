import SwiftUI
import SwiftData

struct ReportView: View {
    @Query(sort: \LabReport.date, order: .reverse) private var reports: [LabReport]
    @Query(sort: \HRTPlan.updatedAt, order: .reverse) private var plans: [HRTPlan]
    @Query(sort: \DailyHRTCheckin.date, order: .reverse) private var checkins: [DailyHRTCheckin]
    @AppStorage("appLanguage") private var appLanguage = "zh-Hans"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    GroupBox(AppLocalization.text("report.section.clinician", lang: appLanguage)) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(AppLocalization.text("report.generated", lang: appLanguage)): \(formattedDate(Date()))")
                            Text(AppLocalization.text("report.disclaimer", lang: appLanguage))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .guideAnchor(GuideAnchorID.briefSection)

                    GroupBox(AppLocalization.text("report.section.current_pattern", lang: appLanguage)) {
                        if let currentPlan = plans.first {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("\(AppLocalization.text("hrt.plan.estrogen", lang: appLanguage))：\(currentPlan.estrogenScheduleText) · \(currentPlan.route.displayName)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text("E: \(AppLocalization.medicationDisplayName(currentPlan.estrogenMedicationName, lang: appLanguage))")
                                if let estrogenDoseMg = currentPlan.estrogenDoseMg {
                                    Text("\(estrogenDoseMg, specifier: "%.2f") mg")
                                        .foregroundStyle(.secondary)
                                }
                                if let antiAndrogenMedicationName = currentPlan.antiAndrogenMedicationName,
                                   !antiAndrogenMedicationName.isEmpty {
                                    Text("\(AppLocalization.text("hrt.plan.anti_androgen", lang: appLanguage))：\(currentPlan.antiAndrogenScheduleText)")
                                        .foregroundStyle(.secondary)
                                    Text("AA: \(AppLocalization.medicationDisplayName(antiAndrogenMedicationName, lang: appLanguage))")
                                    if let antiAndrogenDoseMg = currentPlan.antiAndrogenDoseMg {
                                        Text("\(antiAndrogenDoseMg, specifier: "%.2f") mg")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Text("\(AppLocalization.text("hrt.plan.updated", lang: appLanguage)): \(formattedDateTime(currentPlan.updatedAt))")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text(AppLocalization.text("report.no_plan", lang: appLanguage))
                                .foregroundStyle(.secondary)
                        }
                    }

                    GroupBox(AppLocalization.text("report.section.adherence", lang: appLanguage)) {
                        let last7 = checkins.prefix(7)
                        if last7.isEmpty {
                            Text(AppLocalization.text("report.no_checkins", lang: appLanguage))
                                .foregroundStyle(.secondary)
                        } else {
                            let takenCount = last7.filter(\.didTakeMedication).count
                            Text(AppLocalization.format("report.taken_days", takenCount, last7.count, lang: appLanguage))
                                .font(.subheadline)
                        }
                    }

                    GroupBox(AppLocalization.text("report.section.recent_results", lang: appLanguage)) {
                        if reports.isEmpty {
                            Text(AppLocalization.text("report.no_data", lang: appLanguage))
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(reports.prefix(10)) { report in
                                    Text("• \(formattedDate(report.date)): E2 \(report.estradiolValue, specifier: "%.1f") \(report.estradiolUnit.rawValue), T \(report.testosteroneValue, specifier: "%.1f") \(report.testosteroneUnit.rawValue)")
                                }
                            }
                        }
                    }

                    GroupBox(AppLocalization.text("report.section.rule_suggestion", lang: appLanguage)) {
                        Text(suggestionText)
                            .font(.subheadline)
                    }

                    GroupBox(AppLocalization.text("report.section.resources", lang: appLanguage)) {
                        VStack(alignment: .leading, spacing: 10) {
                            NavigationLink(AppLocalization.text("report.open_resources", lang: appLanguage)) {
                                MTFWikiLocalResourcesView()
                            }

                            Text(AppLocalization.text("report.source_credit", lang: appLanguage))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                    }
                }
                .padding()
            }
            .navigationTitle(AppLocalization.text("report.title", lang: appLanguage))
        }
    }

    private var suggestionText: String {
        guard let latest = reports.first else {
            return AppLocalization.text("report.no_trigger", lang: appLanguage)
        }
        return "\(latest.interpretation.displayName)；\(latest.suggestion.displayName)"
    }

    private func formattedDate(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle(date: .abbreviated, time: .omitted)
                .locale(Locale(identifier: appLanguage))
        )
    }

    private func formattedDateTime(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle(date: .abbreviated, time: .shortened)
                .locale(Locale(identifier: appLanguage))
        )
    }
}
