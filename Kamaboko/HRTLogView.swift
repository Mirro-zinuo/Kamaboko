import SwiftUI
import SwiftData

struct HRTLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \HRTPlan.updatedAt, order: .reverse) private var plans: [HRTPlan]
    @Query(sort: \DailyHRTCheckin.date, order: .reverse) private var checkins: [DailyHRTCheckin]
    @AppStorage("hrtStartDate") private var hrtStartDateTimestamp: Double = Date().timeIntervalSince1970
    @AppStorage("birthDate") private var birthDateTimestamp: Double = Date().timeIntervalSince1970
    @AppStorage("appLanguage") private var appLanguage = "zh-Hans"
    @AppStorage("lastLabCheckDate") private var lastLabCheckTimestamp: Double = Date().timeIntervalSince1970
    @AppStorage("labCheckIntervalWeeks") private var labCheckIntervalWeeks: Int = 8
    @State private var showingPlanEditor = false
    @State private var burstProgress: CGFloat = 0
    @State private var burstVisible = false
    @State private var encouragementMessage = ""
    @State private var displayedDayCount = 0
    @State private var previousDayCount = 0
    @State private var dayFlipProgress: CGFloat = 1
    @State private var showDayIncrement = false

    private var encouragementPool: [String] {
        switch appLanguage {
        case "en":
            return [
                "Our very existence is the greatest resistance against malice.",
                "You are worth being proud of today.",
                "You are your best self.",
                "You are working toward who you want to become.",
                "Every day you keep going matters.",
                "I love you, and please love yourself too.",
                "I'm with you from the other side of this code. You're not alone.",
                "You did great today."
            ]
        case "zh-Hant":
            return [
                "我們的存在，就是對惡意最大的反抗。",
                "今天的你也很值得驕傲！",
                "你是最好的自己。",
                "你在為成為想要成為的樣子而努力。",
                "你的每一天堅持都有意義。",
                "我愛你，也請你愛你自己。",
                "我在程式碼的另一端陪著你，你不是一個人。",
                "今天的你也很棒。"
            ]
        default:
            return [
                "我们的存在，就是对恶意最大的反抗。",
                "今天的你也很值得骄傲！",
                "你是最好的自己。",
                "你在为成为想要成为样子而努力。",
                "你的每一天坚持都有意义。",
                "我爱你，也请你爱你自己。",
                "我在代码的另一端陪着你，你不是一个人。",
                "今天的你也很棒。"
            ]
        }
    }

    private let transBlue = Color(red: 0.36, green: 0.81, blue: 0.98)   // #5BCEFA
    private let transPink = Color(red: 0.96, green: 0.66, blue: 0.72)   // #F5A9B8

    private var currentPlan: HRTPlan? { plans.first }

    private var todayCheckin: DailyHRTCheckin? {
        checkins.first(where: { Calendar.current.isDateInToday($0.date) })
    }

    private var hrtDayCount: Int? {
        let checkinDays = Array(
            Set(
                checkins
                    .filter(\.didTakeMedication)
                    .map { Calendar.current.startOfDay(for: $0.date) }
            )
        ).sorted()

        guard let firstCheckinDay = checkinDays.first else { return nil }

        let startDate = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: hrtStartDateTimestamp))
        let initialDiff = Calendar.current.dateComponents([.day], from: startDate, to: firstCheckinDay).day ?? 0
        let initialDay = max(1, initialDiff + 1)

        return initialDay + (checkinDays.count - 1)
    }

    private var dayCountText: String {
        if displayedDayCount > 0 {
            return AppLocalization.format("hrt.day_count", displayedDayCount, lang: appLanguage)
        }
        return AppLocalization.text("hrt.day_count_start", lang: appLanguage)
    }

    private var checkinStatusText: String {
        todayCheckin?.didTakeMedication == true
            ? AppLocalization.text("hrt.checked_today", lang: appLanguage)
            : AppLocalization.text("hrt.not_checked_today", lang: appLanguage)
    }

    private var checkinTimeText: String {
        if let todayCheckin {
            return todayCheckin.date.formatted(date: .omitted, time: .shortened)
        }
        return currentPlan == nil
            ? AppLocalization.text("hrt.prompt_set_plan", lang: appLanguage)
            : AppLocalization.text("hrt.prompt_tap_checkin", lang: appLanguage)
    }

    private var isBirthdayToday: Bool {
        let birthDate = Date(timeIntervalSince1970: birthDateTimestamp)
        let birthComponents = Calendar.current.dateComponents([.month, .day], from: birthDate)
        let todayComponents = Calendar.current.dateComponents([.month, .day], from: .now)
        return birthComponents.month == todayComponents.month && birthComponents.day == todayComponents.day
    }

    private var nextLabCheckDate: Date {
        let lastDate = Date(timeIntervalSince1970: lastLabCheckTimestamp)
        return Calendar.current.date(byAdding: .day, value: labCheckIntervalWeeks * 7, to: lastDate) ?? lastDate
    }

    private var labCheckCountdownText: String {
        let today = Calendar.current.startOfDay(for: .now)
        let target = Calendar.current.startOfDay(for: nextLabCheckDate)
        let days = Calendar.current.dateComponents([.day], from: today, to: target).day ?? 0
        if days > 0 {
            return AppLocalization.format("hrt.check.in_days", days, lang: appLanguage)
        }
        if days == 0 {
            return AppLocalization.text("hrt.check.today", lang: appLanguage)
        }
        return AppLocalization.format("hrt.check.overdue", -days, lang: appLanguage)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundStyle(.secondary)
                    Text(labCheckCountdownText)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                }
                .padding(.horizontal)

                VStack(spacing: 18) {
                    Button {
                        let didCheckIn = toggleTodayCheckin()
                        if didCheckIn {
                            triggerBurst()
                            showEncouragement()
                        }
                    }
                    label: {
                        ZStack {
                            VStack(spacing: 8) {
                                Image(systemName: todayCheckin?.didTakeMedication == true ? "arrow.uturn.backward.circle.fill" : "checkmark")
                                    .font(.system(size: 30, weight: .bold))
                                dayCountFlipView
                                Text(checkinStatusText)
                                    .font(.subheadline.weight(.semibold))
                                Text(checkinTimeText)
                                    .font(.caption)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                            }
                            .foregroundStyle(.white)
                            .padding(16)

                            if burstVisible {
                                ZStack {
                                    Circle()
                                        .fill(
                                            RadialGradient(
                                                colors: [
                                                    transPink.opacity(0.85),
                                                    transBlue.opacity(0.55),
                                                    .white.opacity(0.1),
                                                    .clear
                                                ],
                                                center: .center,
                                                startRadius: 0,
                                                endRadius: 120
                                            )
                                        )
                                        .scaleEffect(0.2 + burstProgress * 2.2)
                                        .opacity(1 - burstProgress)
                                        .blur(radius: 2 + 10 * burstProgress)

                                    Circle()
                                        .stroke(
                                            AngularGradient(
                                                colors: [transBlue, .white, transPink, .white, transBlue],
                                                center: .center
                                            ),
                                            lineWidth: 8
                                        )
                                        .scaleEffect(0.2 + burstProgress * 1.5)
                                        .opacity(1 - burstProgress)
                                }
                            }
                        }
                        .frame(width: 180, height: 180)
                        .background(
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: todayCheckin?.didTakeMedication == true
                                            ? [
                                                transPink,
                                                Color(red: 0.92, green: 0.56, blue: 0.74)
                                            ]
                                            : [
                                                transBlue,
                                                Color(red: 0.28, green: 0.72, blue: 0.95)
                                            ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                    }
                    .disabled(currentPlan == nil)
                    .guideAnchor(GuideAnchorID.hrtCheckinButton)

                    if !encouragementMessage.isEmpty {
                        Text(encouragementMessage)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .transition(.opacity.combined(with: .scale))
                    }
                }
                .padding(22)
                .padding(.horizontal)
                .frame(maxHeight: .infinity)
                .onAppear {
                    displayedDayCount = hrtDayCount ?? 0
                    previousDayCount = displayedDayCount
                }
                .onChange(of: hrtDayCount) { _, newValue in
                    let newCount = newValue ?? 0
                    if newCount > displayedDayCount {
                        previousDayCount = displayedDayCount
                        dayFlipProgress = 0
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                            displayedDayCount = newCount
                            dayFlipProgress = 1
                        }
                        showDayIncrement = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                            withAnimation(.easeOut(duration: 0.25)) {
                                showDayIncrement = false
                            }
                        }
                    } else {
                        displayedDayCount = newCount
                        previousDayCount = newCount
                        dayFlipProgress = 1
                    }
                }

                VStack(spacing: 10) {
                    GroupBox(AppLocalization.text("hrt.current_plan", lang: appLanguage)) {
                        if let currentPlan {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("\(AppLocalization.text("hrt.plan.estrogen", lang: appLanguage))：\(currentPlan.estrogenScheduleText) · \(currentPlan.route.displayName)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Text("E: \(AppLocalization.medicationDisplayName(currentPlan.estrogenMedicationName, lang: appLanguage))")
                                    .font(.subheadline)
                                if let estrogenDoseMg = currentPlan.estrogenDoseMg {
                                    Text("\(estrogenDoseMg, specifier: "%.2f") mg")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                if let antiAndrogenMedicationName = currentPlan.antiAndrogenMedicationName,
                                   !antiAndrogenMedicationName.isEmpty {
                                    Text("\(AppLocalization.text("hrt.plan.anti_androgen", lang: appLanguage))：\(currentPlan.antiAndrogenScheduleText)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("AA: \(AppLocalization.medicationDisplayName(antiAndrogenMedicationName, lang: appLanguage))")
                                        .font(.subheadline)
                                    if let antiAndrogenDoseMg = currentPlan.antiAndrogenDoseMg {
                                        Text("\(antiAndrogenDoseMg, specifier: "%.2f") mg")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                if let note = currentPlan.note, !note.isEmpty {
                                    Text(note)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Text("\(AppLocalization.text("hrt.plan.updated", lang: appLanguage)): \(formattedDateTime(currentPlan.updatedAt))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text(AppLocalization.text("hrt.no_plan", lang: appLanguage))
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !checkins.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(AppLocalization.text("hrt.recent_checkins", lang: appLanguage))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            ForEach(checkins.prefix(5)) { checkin in
                                HStack {
                                    Text(formattedDateTime(checkin.date))
                                        .font(.caption)
                                    Spacer()
                                    Text(checkin.didTakeMedication
                                        ? AppLocalization.text("hrt.taken", lang: appLanguage)
                                        : AppLocalization.text("hrt.skipped", lang: appLanguage)
                                    )
                                        .font(.caption)
                                        .foregroundStyle(checkin.didTakeMedication ? .green : .orange)
                                }
                            }
                        }
                    }
                    Button(currentPlan == nil
                        ? AppLocalization.text("hrt.set_plan", lang: appLanguage)
                        : AppLocalization.text("hrt.edit_plan", lang: appLanguage)
                    ) {
                        showingPlanEditor = true
                    }
                    .font(.footnote)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .navigationTitle(AppLocalization.text("hrt.title", lang: appLanguage))
            .toolbar {
                Button {
                    showingPlanEditor = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .guideAnchor(GuideAnchorID.hrtPlanButton)
            }
            .sheet(isPresented: $showingPlanEditor) {
                PlanEditorView(plan: currentPlan)
            }
            .onReceive(NotificationCenter.default.publisher(for: .guideOpenPlanEditor)) { _ in
                showingPlanEditor = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .guideTriggerCheckin)) { _ in
                let didCheckIn = toggleTodayCheckin()
                if didCheckIn {
                    triggerBurst()
                    showEncouragement()
                }
            }
        }
    }

    private func toggleTodayCheckin() -> Bool {
        if let todayCheckin {
            modelContext.delete(todayCheckin)
            return false
        }
        let checkin = DailyHRTCheckin(date: .now, didTakeMedication: true)
        modelContext.insert(checkin)
        return true
    }

    private func triggerBurst() {
        burstVisible = true
        burstProgress = 0
        withAnimation(.easeOut(duration: 0.75)) {
            burstProgress = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            burstVisible = false
            burstProgress = 0
        }
    }

    private func showEncouragement() {
        withAnimation(.easeOut(duration: 0.2)) {
            if isBirthdayToday {
                encouragementMessage = AppLocalization.text("hrt.birthday_message", lang: appLanguage)
            } else {
                encouragementMessage = encouragementPool.randomElement() ?? AppLocalization.text("hrt.done_today", lang: appLanguage)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            withAnimation(.easeOut(duration: 0.25)) {
                encouragementMessage = ""
            }
        }
    }

    private var dayCountFlipView: some View {
        ZStack {
            if displayedDayCount > 0 {
                Text(AppLocalization.format("hrt.day_count", previousDayCount, lang: appLanguage))
                    .font(.headline)
                    .opacity(1 - dayFlipProgress)
                    .rotation3DEffect(
                        .degrees(Double(dayFlipProgress) * -90),
                        axis: (x: 1, y: 0, z: 0)
                    )
            }

            Text(dayCountText)
                .font(.headline)
                .rotation3DEffect(
                    .degrees((1 - Double(dayFlipProgress)) * 90),
                    axis: (x: 1, y: 0, z: 0)
                )
                .opacity(dayFlipProgress)
                .overlay(alignment: .topTrailing) {
                    if showDayIncrement {
                        Text(AppLocalization.text("common.plus_one", lang: appLanguage))
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.95))
                            .offset(x: 6, y: -6)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
        }
    }

    private func formattedDateTime(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle(date: .abbreviated, time: .shortened)
                .locale(Locale(identifier: appLanguage))
        )
    }
}

struct PlanEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("appLanguage") private var appLanguage = "zh-Hans"

    let plan: HRTPlan?

    private let oralEstrogenOptions = ["progynova", "nokunfu", "custom"]
    private let gelEstrogenOptions = ["estrogel", "estradiol_gel", "custom"]
    private let injectionEstrogenOptions = ["estradiol_valerate_inj", "estradiol_benzoate_inj", "custom"]
    private let antiAndrogenOptions = ["spironolactone", "cyproterone", "bicalutamide", "custom"]

    @State private var route: AdministrationRoute = .oral
    @State private var estrogenEveryValue = 1
    @State private var estrogenEveryUnit: DoseIntervalUnit = .day
    @State private var selectedEstrogenOption = "progynova"
    @State private var customEstrogenName = ""
    @State private var estrogenDoseText = ""
    @State private var antiAndrogenEveryValue = 1
    @State private var antiAndrogenEveryUnit: DoseIntervalUnit = .day
    @State private var selectedAntiAndrogenOption = "spironolactone"
    @State private var customAntiAndrogenName = ""
    @State private var antiAndrogenDoseText = ""
    @State private var note = ""

    var canSave: Bool {
        !resolvedEstrogenMedicationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var estrogenOptionsForRoute: [String] {
        switch route {
        case .oral:
            return oralEstrogenOptions
        case .gel:
            return gelEstrogenOptions
        case .injection:
            return injectionEstrogenOptions
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(AppLocalization.text("plan.section.estrogen", lang: appLanguage)) {
                    Picker(AppLocalization.text("plan.route", lang: appLanguage), selection: $route) {
                        ForEach(AdministrationRoute.allCases) { value in
                            Text(value.displayName).tag(value)
                        }
                    }
                    Stepper(
                        AppLocalization.format("plan.freq", estrogenEveryValue, estrogenEveryUnit.displayName, lang: appLanguage),
                        value: $estrogenEveryValue,
                        in: 1...30
                    )
                    Picker(AppLocalization.text("plan.freq_unit", lang: appLanguage), selection: $estrogenEveryUnit) {
                        ForEach(DoseIntervalUnit.allCases) { value in
                            Text(value.displayName).tag(value)
                        }
                    }
                    Picker(AppLocalization.text("plan.medication", lang: appLanguage), selection: $selectedEstrogenOption) {
                        ForEach(estrogenOptionsForRoute, id: \.self) { option in
                            Text(AppLocalization.medicationDisplayName(option, lang: appLanguage)).tag(option)
                        }
                    }
                    if selectedEstrogenOption == "custom" {
                        TextField(AppLocalization.text("plan.medication_name", lang: appLanguage), text: $customEstrogenName)
                    }
                    TextField(AppLocalization.text("plan.dose_optional", lang: appLanguage), text: $estrogenDoseText)
                        .keyboardType(.decimalPad)
                }

                Section(AppLocalization.text("plan.section.aa", lang: appLanguage)) {
                    Stepper(
                        AppLocalization.format("plan.freq", antiAndrogenEveryValue, antiAndrogenEveryUnit.displayName, lang: appLanguage),
                        value: $antiAndrogenEveryValue,
                        in: 1...30
                    )
                    Picker(AppLocalization.text("plan.freq_unit", lang: appLanguage), selection: $antiAndrogenEveryUnit) {
                        ForEach(DoseIntervalUnit.allCases) { value in
                            Text(value.displayName).tag(value)
                        }
                    }
                    Picker(AppLocalization.text("plan.medication", lang: appLanguage), selection: $selectedAntiAndrogenOption) {
                        ForEach(antiAndrogenOptions, id: \.self) { option in
                            Text(AppLocalization.medicationDisplayName(option, lang: appLanguage)).tag(option)
                        }
                    }
                    if selectedAntiAndrogenOption == "custom" {
                        TextField(AppLocalization.text("plan.medication_name", lang: appLanguage), text: $customAntiAndrogenName)
                    }
                    TextField(AppLocalization.text("plan.dose_optional", lang: appLanguage), text: $antiAndrogenDoseText)
                        .keyboardType(.decimalPad)
                }

                TextField(AppLocalization.text("plan.note_optional", lang: appLanguage), text: $note)
            }
            .navigationTitle(AppLocalization.text("plan.title", lang: appLanguage))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(AppLocalization.text("plan.cancel", lang: appLanguage)) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(AppLocalization.text("plan.save", lang: appLanguage)) {
                        savePlan()
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear {
                guard let plan else { return }
                route = plan.route
                estrogenEveryValue = max(1, plan.estrogenEveryValue)
                estrogenEveryUnit = plan.estrogenEveryUnit
                antiAndrogenEveryValue = max(1, plan.antiAndrogenEveryValue)
                antiAndrogenEveryUnit = plan.antiAndrogenEveryUnit

                let estrogenID = AppLocalization.medicationCanonicalID(plan.estrogenMedicationName)
                if estrogenOptionsForRoute.contains(estrogenID) {
                    selectedEstrogenOption = estrogenID
                    customEstrogenName = ""
                } else {
                    selectedEstrogenOption = "custom"
                    customEstrogenName = plan.estrogenMedicationName
                }
                estrogenDoseText = plan.estrogenDoseMg.map { String($0) } ?? ""
                if let antiAndrogenName = plan.antiAndrogenMedicationName, !antiAndrogenName.isEmpty {
                    let antiAndrogenID = AppLocalization.medicationCanonicalID(antiAndrogenName)
                    if antiAndrogenOptions.contains(antiAndrogenID) {
                        selectedAntiAndrogenOption = antiAndrogenID
                        customAntiAndrogenName = ""
                    } else {
                        selectedAntiAndrogenOption = "custom"
                        customAntiAndrogenName = antiAndrogenName
                    }
                } else {
                    selectedAntiAndrogenOption = antiAndrogenOptions.first ?? "spironolactone"
                    customAntiAndrogenName = ""
                }
                antiAndrogenDoseText = plan.antiAndrogenDoseMg.map { String($0) } ?? ""
                note = plan.note ?? ""
            }
            .onChange(of: route) { _, _ in
                if !estrogenOptionsForRoute.contains(selectedEstrogenOption) {
                    selectedEstrogenOption = estrogenOptionsForRoute.first ?? "custom"
                }
                if selectedEstrogenOption != "custom" {
                    customEstrogenName = ""
                }
            }
        }
    }

    private func savePlan() {
        let estrogenDose = parseDecimal(estrogenDoseText)
        let antiAndrogenDose = parseDecimal(antiAndrogenDoseText)
        let cleanedAntiAndrogenName = resolvedAntiAndrogenMedicationName.trimmingCharacters(in: .whitespacesAndNewlines)

        if let plan {
            plan.updatedAt = .now
            plan.frequencyRaw = DoseFrequency.daily.rawValue
            plan.routeRaw = route.rawValue
            plan.estrogenEveryValue = estrogenEveryValue
            plan.estrogenEveryUnitRaw = estrogenEveryUnit.rawValue
            plan.estrogenMedicationName = resolvedEstrogenMedicationName.trimmingCharacters(in: .whitespacesAndNewlines)
            plan.estrogenDoseMg = estrogenDose
            plan.antiAndrogenEveryValue = antiAndrogenEveryValue
            plan.antiAndrogenEveryUnitRaw = antiAndrogenEveryUnit.rawValue
            plan.antiAndrogenMedicationName = cleanedAntiAndrogenName.isEmpty ? nil : cleanedAntiAndrogenName
            plan.antiAndrogenDoseMg = antiAndrogenDose
            plan.note = note.isEmpty ? nil : note
            return
        }

        let newPlan = HRTPlan(
            frequency: .daily,
            route: route,
            estrogenEveryValue: estrogenEveryValue,
            estrogenEveryUnit: estrogenEveryUnit,
            estrogenMedicationName: resolvedEstrogenMedicationName.trimmingCharacters(in: .whitespacesAndNewlines),
            estrogenDoseMg: estrogenDose,
            antiAndrogenEveryValue: antiAndrogenEveryValue,
            antiAndrogenEveryUnit: antiAndrogenEveryUnit,
            antiAndrogenMedicationName: cleanedAntiAndrogenName.isEmpty ? nil : cleanedAntiAndrogenName,
            antiAndrogenDoseMg: antiAndrogenDose,
            note: note.isEmpty ? nil : note
        )
        modelContext.insert(newPlan)
    }

    private var resolvedEstrogenMedicationName: String {
        selectedEstrogenOption == "custom" ? customEstrogenName : selectedEstrogenOption
    }

    private var resolvedAntiAndrogenMedicationName: String {
        selectedAntiAndrogenOption == "custom" ? customAntiAndrogenName : selectedAntiAndrogenOption
    }

    private func parseDecimal(_ value: String) -> Double? {
        let normalized = value.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }
}
