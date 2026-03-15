import SwiftUI
import UserNotifications

struct ReminderView: View {
    @AppStorage("lastLabCheckDate") private var lastLabCheckTimestamp: Double = Date().timeIntervalSince1970
    @AppStorage("labCheckIntervalWeeks") private var intervalWeeks: Int = 8
    @State private var statusMessage = ""

    private var lastLabCheckDate: Date {
        Date(timeIntervalSince1970: lastLabCheckTimestamp)
    }

    private var lastLabCheckBinding: Binding<Date> {
        Binding(
            get: { Date(timeIntervalSince1970: lastLabCheckTimestamp) },
            set: { newValue in
                lastLabCheckTimestamp = newValue.timeIntervalSince1970
            }
        )
    }

    private var nextCheckDate: Date {
        Calendar.current.date(byAdding: .day, value: intervalWeeks * 7, to: lastLabCheckDate) ?? lastLabCheckDate
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Schedule") {
                    DatePicker("Last lab check", selection: lastLabCheckBinding, displayedComponents: .date)

                    Stepper(
                        "\(String(localized: "reminder.interval")): \(intervalWeeks) \(String(localized: "reminder.weeks"))",
                        value: $intervalWeeks,
                        in: 2...16,
                        step: 1
                    )

                    HStack {
                        Text("Next check")
                        Spacer()
                        Text(nextCheckDate.formatted(date: .abbreviated, time: .omitted))
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Notification") {
                    Button("Enable reminder notification") {
                        Task {
                            await scheduleReminder()
                        }
                    }
                    if !statusMessage.isEmpty {
                        Text(statusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Text("This reminder supports follow-up planning and does not replace clinician guidance.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Reminders")
        }
    }

    private func scheduleReminder() async {
        let center = UNUserNotificationCenter.current()

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            guard granted else {
                statusMessage = String(localized: "reminder.permission_not_granted")
                return
            }

            center.removePendingNotificationRequests(withIdentifiers: ["lab-check-reminder"])

            let content = UNMutableNotificationContent()
            content.title = String(localized: "reminder.notification.title")
            content.body = String(localized: "reminder.notification.body")
            content.sound = .default

            let dateComponents = Calendar.current.dateComponents(
                [.year, .month, .day],
                from: nextCheckDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            let request = UNNotificationRequest(identifier: "lab-check-reminder", content: content, trigger: trigger)
            try await center.add(request)

            statusMessage = "\(String(localized: "reminder.scheduled_for")) \(nextCheckDate.formatted(date: .abbreviated, time: .omitted))."
        } catch {
            statusMessage = "\(String(localized: "reminder.failed_prefix")) \(error.localizedDescription)"
        }
    }
}
