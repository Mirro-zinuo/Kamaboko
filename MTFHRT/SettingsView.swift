import SwiftUI
import PhotosUI
import UIKit
import UserNotifications

struct SettingsView: View {
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

    @State private var selectedAvatarItem: PhotosPickerItem?
    @State private var reminderStatusMessage = ""
    @State private var labReminderStatusMessage = ""

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
