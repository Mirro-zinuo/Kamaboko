import SwiftUI
import SwiftData
import PhotosUI
import UIKit
import UserNotifications

struct SettingsView: View {
    @Query(sort: \LabReport.date, order: .reverse) private var reports: [LabReport]
    @AppStorage("profileName") private var profileName = ""
    @AppStorage("birthDate") private var birthDateTimestamp: Double = Date().timeIntervalSince1970
    @AppStorage("hrtStartDate") private var hrtStartDateTimestamp: Double = Date().timeIntervalSince1970
    @AppStorage("appLanguage") private var appLanguage = "zh-Hans"
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("hasCompletedInteractiveGuide") private var hasCompletedInteractiveGuide = false
    @AppStorage("profileAvatarFileName") private var profileAvatarFileName = ""
    @AppStorage("dailyHRTReminderEnabled") private var dailyHRTReminderEnabled = false
    @AppStorage("dailyHRTReminderHour") private var dailyHRTReminderHour = 21
    @AppStorage("dailyHRTReminderMinute") private var dailyHRTReminderMinute = 0
    @AppStorage("lastLabCheckDate") private var lastLabCheckTimestamp: Double = Date().timeIntervalSince1970
    @AppStorage("labCheckIntervalWeeks") private var labCheckIntervalWeeks: Int = 8
    @AppStorage("xaiApiKey") private var xaiApiKey = ""
    @AppStorage("xaiBaseURL") private var xaiBaseURL = "https://api.x.ai"
    @AppStorage("xaiModel") private var xaiModel = "grok-4-fast"

    @State private var selectedAvatarItem: PhotosPickerItem?
    @State private var reminderStatusMessage = ""
    @State private var labReminderStatusMessage = ""
    @State private var aiLabSuggestion: XAIChatClient.LabCheckAISuggestion?
    @State private var aiLabSuggestionMessage = ""
    @State private var aiLabSuggestionError = ""
    @State private var isGeneratingAiLabSuggestion = false

    private let languageOptions: [(label: String, value: String)] = [
        ("简体中文", "zh-Hans"),
        ("正體中文", "zh-Hant"),
        ("English", "en")
    ]

    private var hrtStartDateBinding: Binding<Date> {
        Binding(
            get: { Date(timeIntervalSince1970: hrtStartDateTimestamp) },
            set: { newValue in
                hrtStartDateTimestamp = newValue.timeIntervalSince1970
            }
        )
    }

    private var birthDateBinding: Binding<Date> {
        Binding(
            get: { Date(timeIntervalSince1970: birthDateTimestamp) },
            set: { newValue in
                birthDateTimestamp = newValue.timeIntervalSince1970
            }
        )
    }

    private var currentAge: Int {
        Calendar.current.dateComponents([.year], from: Date(timeIntervalSince1970: birthDateTimestamp), to: .now).year ?? 0
    }

    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: dailyHRTReminderHour,
                    minute: dailyHRTReminderMinute,
                    second: 0,
                    of: Date()
                ) ?? Date()
            },
            set: { newValue in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                dailyHRTReminderHour = components.hour ?? 21
                dailyHRTReminderMinute = components.minute ?? 0
                if dailyHRTReminderEnabled {
                    Task { await updateDailyHRTReminder() }
                }
            }
        )
    }

    private var lastLabCheckBinding: Binding<Date> {
        Binding(
            get: { Date(timeIntervalSince1970: lastLabCheckTimestamp) },
            set: { newValue in
                lastLabCheckTimestamp = newValue.timeIntervalSince1970
            }
        )
    }

    private var nextLabCheckDate: Date {
        Calendar.current.date(byAdding: .day, value: labCheckIntervalWeeks * 7, to: Date(timeIntervalSince1970: lastLabCheckTimestamp))
            ?? Date(timeIntervalSince1970: lastLabCheckTimestamp)
    }

    private var smartLabSuggestion: LabCheckSuggestion {
        LabCheckAdvisor.suggest(
            hrtStartDate: Date(timeIntervalSince1970: hrtStartDateTimestamp),
            latestReport: reports.first,
            fallbackLastCheckDate: Date(timeIntervalSince1970: lastLabCheckTimestamp)
        )
    }

    private func smartLabReasonText(_ reason: LabCheckSuggestion.Reason) -> String {
        switch reason {
        case .noReport:
            return AppLocalization.text("settings.smart_lab.reason.no_report", lang: appLanguage)
        case .recentAbnormal:
            return AppLocalization.text("settings.smart_lab.reason.abnormal", lang: appLanguage)
        case .earlyHRT:
            return AppLocalization.text("settings.smart_lab.reason.early", lang: appLanguage)
        case .stable:
            return AppLocalization.text("settings.smart_lab.reason.stable", lang: appLanguage)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(AppLocalization.text("settings.profile", lang: appLanguage)) {
                    HStack(spacing: 14) {
                        avatarView

                        PhotosPicker(selection: $selectedAvatarItem, matching: .images) {
                            Label(AppLocalization.text("settings.avatar", lang: appLanguage), systemImage: "camera")
                        }
                    }
                    TextField(AppLocalization.text("settings.name", lang: appLanguage), text: $profileName)
                    DatePicker(AppLocalization.text("settings.birth_date", lang: appLanguage), selection: birthDateBinding, displayedComponents: .date)
                    Text("\(AppLocalization.text("settings.age", lang: appLanguage))：\(max(0, currentAge))")
                        .foregroundStyle(.secondary)
                    DatePicker(AppLocalization.text("settings.hrt_start", lang: appLanguage), selection: hrtStartDateBinding, displayedComponents: .date)
                }

                Section(AppLocalization.text("settings.preferences", lang: appLanguage)) {
                    Picker(AppLocalization.text("settings.language", lang: appLanguage), selection: $appLanguage) {
                        ForEach(languageOptions, id: \.value) { option in
                            Text(option.label).tag(option.value)
                        }
                    }
                }

                Section(AppLocalization.text("settings.ai.title", lang: appLanguage)) {
                    TextField(AppLocalization.text("settings.ai.url", lang: appLanguage), text: $xaiBaseURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    SecureField(AppLocalization.text("settings.ai.key", lang: appLanguage), text: $xaiApiKey)
                    TextField(AppLocalization.text("settings.ai.model", lang: appLanguage), text: $xaiModel)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text(AppLocalization.text("settings.ai.desc", lang: appLanguage))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section(AppLocalization.text("settings.onboarding", lang: appLanguage)) {
                    Button(AppLocalization.text("settings.replay_onboarding", lang: appLanguage)) {
                        hasCompletedInteractiveGuide = false
                        hasSeenOnboarding = false
                    }
                }

                Section(AppLocalization.text("settings.daily_reminder", lang: appLanguage)) {
                    Toggle(AppLocalization.text("settings.enable_daily", lang: appLanguage), isOn: $dailyHRTReminderEnabled)
                        .onChange(of: dailyHRTReminderEnabled) { _, _ in
                            Task { await updateDailyHRTReminder() }
                        }

                    DatePicker(AppLocalization.text("settings.reminder_time", lang: appLanguage), selection: reminderTimeBinding, displayedComponents: .hourAndMinute)
                        .disabled(!dailyHRTReminderEnabled)

                    if !reminderStatusMessage.isEmpty {
                        Text(reminderStatusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section(AppLocalization.text("settings.lab_reminder", lang: appLanguage)) {
                    DatePicker(AppLocalization.text("settings.last_lab", lang: appLanguage), selection: lastLabCheckBinding, displayedComponents: .date)

                    Stepper(
                        AppLocalization.format("settings.lab_interval", labCheckIntervalWeeks, lang: appLanguage),
                        value: $labCheckIntervalWeeks,
                        in: 2...16
                    )

                    let suggestion = smartLabSuggestion
                    HStack {
                        Text(AppLocalization.text("settings.smart_lab", lang: appLanguage))
                        Spacer()
                        Text(formattedDate(suggestion.nextDate))
                            .foregroundStyle(.secondary)
                    }
                    Text(AppLocalization.format("settings.smart_lab.interval", suggestion.intervalWeeks, lang: appLanguage))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(smartLabReasonText(suggestion.reason))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button(AppLocalization.text("settings.smart_lab.apply", lang: appLanguage)) {
                        lastLabCheckTimestamp = suggestion.anchorDate.timeIntervalSince1970
                        labCheckIntervalWeeks = suggestion.intervalWeeks
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text(AppLocalization.text("settings.ai_lab.title", lang: appLanguage))
                            .font(.subheadline.weight(.semibold))
                        Text(AppLocalization.text("settings.ai_lab.disclaimer", lang: appLanguage))
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        if let aiLabSuggestion {
                            Text(AppLocalization.format("settings.ai_lab.interval", aiLabSuggestion.intervalWeeks, lang: appLanguage))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Text(aiLabSuggestion.reason)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Button(AppLocalization.text("settings.ai_lab.apply", lang: appLanguage)) {
                                labCheckIntervalWeeks = max(2, aiLabSuggestion.intervalWeeks)
                            }
                        }

                        if !aiLabSuggestionMessage.isEmpty {
                            Text(aiLabSuggestionMessage)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        if !aiLabSuggestionError.isEmpty {
                            Text(aiLabSuggestionError)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        Button(isGeneratingAiLabSuggestion
                            ? AppLocalization.text("settings.ai_lab.generating", lang: appLanguage)
                            : AppLocalization.text("settings.ai_lab.generate", lang: appLanguage)
                        ) {
                            Task { await generateAiLabSuggestion() }
                        }
                        .disabled(isGeneratingAiLabSuggestion)
                    }

                    HStack {
                        Text(AppLocalization.text("settings.next_lab", lang: appLanguage))
                        Spacer()
                        Text(formattedDate(nextLabCheckDate))
                            .foregroundStyle(.secondary)
                    }

                    Button(AppLocalization.text("settings.schedule_lab", lang: appLanguage)) {
                        Task { await scheduleLabReminder() }
                    }

                    if !labReminderStatusMessage.isEmpty {
                        Text(labReminderStatusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(AppLocalization.text("settings.title", lang: appLanguage))
            .onChange(of: selectedAvatarItem) { _, newItem in
                guard let newItem else { return }
                Task { await saveAvatar(from: newItem) }
            }
            .task {
                if dailyHRTReminderEnabled {
                    await updateDailyHRTReminder()
                }
            }
        }
    }

    @ViewBuilder
    private var avatarView: some View {
        if let image = loadAvatarImage() {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 64, height: 64)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(.gray.opacity(0.2))
                .frame(width: 64, height: 64)
                .overlay {
                    Image(systemName: "person.fill")
                        .foregroundStyle(.secondary)
                }
        }
    }

    @MainActor
    private func saveAvatar(from item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        guard let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }

        let fileName = "\(UUID().uuidString).jpg"
        let fileURL = directory.appendingPathComponent(fileName)

        do {
            try data.write(to: fileURL, options: .atomic)
            if !profileAvatarFileName.isEmpty {
                let oldURL = directory.appendingPathComponent(profileAvatarFileName)
                if FileManager.default.fileExists(atPath: oldURL.path) {
                    try? FileManager.default.removeItem(at: oldURL)
                }
            }
            profileAvatarFileName = fileName
        } catch {
            return
        }
    }

    private func loadAvatarImage() -> UIImage? {
        guard !profileAvatarFileName.isEmpty else { return nil }
        guard let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let fileURL = directory.appendingPathComponent(profileAvatarFileName)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }

    @MainActor
    private func updateDailyHRTReminder() async {
        let center = UNUserNotificationCenter.current()
        let identifier = "daily-hrt-reminder"

        if !dailyHRTReminderEnabled {
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
            reminderStatusMessage = AppLocalization.text("settings.reminder.off", lang: appLanguage)
            return
        }

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            guard granted else {
                dailyHRTReminderEnabled = false
                reminderStatusMessage = AppLocalization.text("settings.notification_denied", lang: appLanguage)
                return
            }

            center.removePendingNotificationRequests(withIdentifiers: [identifier])

            let content = UNMutableNotificationContent()
            content.title = AppLocalization.text("settings.daily.title", lang: appLanguage)
            content.body = AppLocalization.text("settings.daily.body", lang: appLanguage)
            content.sound = .default

            var dateComponents = DateComponents()
            dateComponents.hour = dailyHRTReminderHour
            dateComponents.minute = dailyHRTReminderMinute

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            try await center.add(request)

            reminderStatusMessage = AppLocalization.format("settings.reminder.set_to", formattedReminderTime(), lang: appLanguage)
        } catch {
            dailyHRTReminderEnabled = false
            reminderStatusMessage = AppLocalization.format("settings.reminder.failed", error.localizedDescription, lang: appLanguage)
        }
    }

    private func formattedReminderTime() -> String {
        let date = Calendar.current.date(
            bySettingHour: dailyHRTReminderHour,
            minute: dailyHRTReminderMinute,
            second: 0,
            of: Date()
        ) ?? Date()
        return date.formatted(
            Date.FormatStyle(date: .omitted, time: .shortened)
                .locale(Locale(identifier: appLanguage))
        )
    }

    private func formattedDate(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle(date: .abbreviated, time: .omitted)
                .locale(Locale(identifier: appLanguage))
        )
    }

    @MainActor
    private func generateAiLabSuggestion() async {
        aiLabSuggestionError = ""
        aiLabSuggestionMessage = ""
        aiLabSuggestion = nil

        guard !xaiApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            aiLabSuggestionError = AppLocalization.text("settings.ai_lab.missing_key", lang: appLanguage)
            return
        }

        isGeneratingAiLabSuggestion = true
        defer { isGeneratingAiLabSuggestion = false }

        do {
            let suggestion = try await XAIChatClient.generateLabCheckSuggestion(
                hrtStartDate: Date(timeIntervalSince1970: hrtStartDateTimestamp),
                latestReport: reports.first,
                languageCode: appLanguage,
                apiKey: xaiApiKey,
                baseURL: xaiBaseURL,
                model: xaiModel
            )
            aiLabSuggestion = suggestion
            aiLabSuggestionMessage = AppLocalization.text("settings.ai_lab.done", lang: appLanguage)
        } catch {
            aiLabSuggestionError = AppLocalization.format("settings.ai_lab.failed", error.localizedDescription, lang: appLanguage)
        }
    }

    @MainActor
    private func scheduleLabReminder() async {
        let center = UNUserNotificationCenter.current()
        let identifier = "lab-check-reminder"

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            guard granted else {
                labReminderStatusMessage = AppLocalization.text("settings.notification_denied", lang: appLanguage)
                return
            }

            center.removePendingNotificationRequests(withIdentifiers: [identifier])

            let content = UNMutableNotificationContent()
            content.title = AppLocalization.text("settings.lab.title", lang: appLanguage)
            content.body = AppLocalization.text("settings.lab.body", lang: appLanguage)
            content.sound = .default

            let dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: nextLabCheckDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            try await center.add(request)

            labReminderStatusMessage = AppLocalization.format("settings.lab.scheduled", formattedDate(nextLabCheckDate), lang: appLanguage)
        } catch {
            labReminderStatusMessage = AppLocalization.format("settings.set_failed", error.localizedDescription, lang: appLanguage)
        }
    }
}
