import SwiftUI
import SwiftData

struct ContentView: View {
    private enum MainTab: Hashable {
        case hrt
        case labs
        case brief
        case settings
    }

    private enum GuideStep: Int, CaseIterable {
        case setPlan = 0
        case dailyCheckin
        case uploadLab
        case readInterpretation
        case briefShare
    }

    private enum GuideTargetKind {
        case tab(MainTab)
        case hrtPlanButton
        case hrtCheckinButton
        case labsAddButton
        case labsReportArea
        case briefArea
    }

    private struct GuideTarget {
        let kind: GuideTargetKind
        let frame: CGRect
        let cornerRadius: CGFloat
    }

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LabReport.date, order: .reverse) private var reports: [LabReport]
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("hasCompletedInteractiveGuide") private var hasCompletedInteractiveGuide = false
    @AppStorage("interactiveGuideInProgress") private var interactiveGuideInProgress = false
    @AppStorage("appLanguage") private var appLanguage = "zh-Hans"

    @State private var selectedTab: MainTab = .hrt
    @State private var guideStep: GuideStep?
    @State private var guideAnchors: [String: CGRect] = [:]
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        TabView(selection: $selectedTab) {
            HRTLogView()
                .tag(MainTab.hrt)
                .tabItem { Label(AppLocalization.text("tab.hrt", lang: appLanguage), systemImage: "pills") }

            LabsListView()
                .tag(MainTab.labs)
                .tabItem { Label(AppLocalization.text("tab.labs", lang: appLanguage), systemImage: "waveform.path.ecg") }

            ReportView()
                .tag(MainTab.brief)
                .tabItem { Label(AppLocalization.text("tab.brief", lang: appLanguage), systemImage: "doc.text") }

            SettingsView()
                .tag(MainTab.settings)
                .tabItem { Label(AppLocalization.text("tab.settings", lang: appLanguage), systemImage: "gearshape") }
        }
        .onPreferenceChange(GuideAnchorPreferenceKey.self) { guideAnchors = $0 }
        .environment(\.locale, Locale(identifier: appLanguage))
        .onAppear { startInteractiveGuideIfNeeded() }
        .onChange(of: hasSeenOnboarding) { _, _ in startInteractiveGuideIfNeeded() }
        .onChange(of: hasCompletedInteractiveGuide) { _, _ in startInteractiveGuideIfNeeded() }
        .fullScreenCover(
            isPresented: Binding(
                get: { !hasSeenOnboarding },
                set: { newValue in
                    if !newValue { hasSeenOnboarding = true }
                }
            )
        ) {
            OnboardingView(hasSeenOnboarding: $hasSeenOnboarding)
        }
        .overlay {
            if shouldShowInteractiveGuide, let step = guideStep {
                GeometryReader { proxy in
                    let target = guideTarget(for: step, in: proxy)
                    guideMask(target: target, in: proxy)
                        .overlay {
                            RoundedRectangle(cornerRadius: target.cornerRadius)
                                .stroke(Color.white, lineWidth: 3)
                                .frame(width: target.frame.width, height: target.frame.height)
                                .position(x: target.frame.midX, y: target.frame.midY)
                        }
                        .overlay {
                            interactiveTooltip(for: step, target: target, in: proxy)
                        }
                        .overlay {
                            Button {
                                handleGuideTap(step: step, target: target.kind)
                            } label: {
                                RoundedRectangle(cornerRadius: target.cornerRadius)
                                    .fill(Color.clear)
                                    .frame(width: target.frame.width, height: target.frame.height)
                            }
                            .position(x: target.frame.midX, y: target.frame.midY)
                        }
                        .transition(.opacity)
                }
                .ignoresSafeArea()
            }
        }
    }

    private var shouldShowInteractiveGuide: Bool {
        hasSeenOnboarding && !hasCompletedInteractiveGuide
    }

    private var isPadLayout: Bool {
        UIDevice.current.userInterfaceIdiom == .pad || horizontalSizeClass == .regular
    }

    private func startInteractiveGuideIfNeeded() {
        guard hasSeenOnboarding, !hasCompletedInteractiveGuide else {
            guideStep = nil
            interactiveGuideInProgress = false
            return
        }
        if guideStep == nil {
            guideStep = .setPlan
            interactiveGuideInProgress = true
        }
    }

    @ViewBuilder
    private func guideMask(target: GuideTarget, in proxy: GeometryProxy) -> some View {
        Path { path in
            path.addRect(CGRect(origin: .zero, size: proxy.size))
            path.addRoundedRect(
                in: target.frame,
                cornerSize: CGSize(width: target.cornerRadius, height: target.cornerRadius)
            )
        }
        .fill(Color.black.opacity(0.62), style: FillStyle(eoFill: true))
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func interactiveTooltip(for step: GuideStep, target: GuideTarget, in proxy: GeometryProxy) -> some View {
        let placeAbove = target.frame.midY > proxy.size.height * (isPadLayout ? 0.62 : 0.55)
        let tooltipY = placeAbove
            ? max(isPadLayout ? 96 : 80, target.frame.minY - (isPadLayout ? 130 : 110))
            : min(proxy.size.height - (isPadLayout ? 140 : 120), target.frame.maxY + (isPadLayout ? 110 : 90))
        let tooltipWidth: CGFloat = isPadLayout ? 440 : 320
        let tooltipX = min(max(target.frame.midX, tooltipWidth / 2 + 16), proxy.size.width - tooltipWidth / 2 - 16)

        VStack(alignment: .leading, spacing: 8) {
            Text(AppLocalization.text("guide.title", lang: appLanguage))
                .font(.headline)
            Text(AppLocalization.format("guide.step_counter", step.rawValue + 1, GuideStep.allCases.count, lang: appLanguage))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(stepTitle(step))
                .font(.subheadline.weight(.semibold))
            Text(stepDescription(step))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack {
                Button(AppLocalization.text("guide.skip", lang: appLanguage)) {
                    hasCompletedInteractiveGuide = true
                    guideStep = nil
                    interactiveGuideInProgress = false
                    cleanupGuideSampleData()
                }
                .buttonStyle(.bordered)
                Spacer()
                Text(appLanguage == "en" ? "Tap highlighted area to continue" : (appLanguage == "zh-Hant" ? "請點擊高亮區域繼續" : "请点击高亮区域继续"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
            }
        }
        .padding(12)
        .frame(maxWidth: tooltipWidth)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .position(x: tooltipX, y: tooltipY)
    }

    private func tabTargetFrame(_ tab: MainTab, in proxy: GeometryProxy) -> CGRect {
        let w = proxy.size.width
        let h = proxy.size.height
        let index: CGFloat
        switch tab {
        case .hrt: index = 0
        case .labs: index = 1
        case .brief: index = 2
        case .settings: index = 3
        }

        if isPadLayout {
            let groupWidth = min(380, max(240, w * 0.34))
            let segment = groupWidth / 4
            let groupStartX = (w - groupWidth) / 2
            let x = groupStartX + segment * (index + 0.5)
            let y = proxy.safeAreaInsets.top + 44
            let targetWidth: CGFloat = min(88, segment * 0.9)
            let targetHeight: CGFloat = 40
            return CGRect(x: x - targetWidth / 2, y: y - targetHeight / 2, width: targetWidth, height: targetHeight)
        } else {
            // Some overlay contexts report an incorrect bottom safe area (often 0).
            let bottomInset = proxy.safeAreaInsets.bottom > 0 ? proxy.safeAreaInsets.bottom : 34
            let y = h - bottomInset - 25
            let segment = w / 4
            let x = segment * (index + 0.5)
            let targetWidth: CGFloat = 68
            let targetHeight: CGFloat = 44
            return CGRect(x: x - targetWidth / 2, y: y - targetHeight / 2, width: targetWidth, height: targetHeight)
        }
    }

    private func topRightButtonFrame(in proxy: GeometryProxy) -> CGRect {
        let size: CGFloat = isPadLayout ? 50 : 44
        let x = proxy.size.width - (isPadLayout ? 22 : 18) - size
        let y = proxy.safeAreaInsets.top + (isPadLayout ? 12 : 10)
        return CGRect(x: x, y: y, width: size, height: size)
    }

    private func guideTarget(for step: GuideStep, in proxy: GeometryProxy) -> GuideTarget {
        func anchored(_ id: String, kind: GuideTargetKind, cornerRadius: CGFloat) -> GuideTarget? {
            guard let frame = guideAnchors[id], frame.width > 1, frame.height > 1 else { return nil }
            return GuideTarget(kind: kind, frame: frame, cornerRadius: cornerRadius)
        }

        switch step {
        case .setPlan:
            if selectedTab != .hrt {
                let frame = tabTargetFrame(.hrt, in: proxy)
                return GuideTarget(kind: .tab(.hrt), frame: frame, cornerRadius: 14)
            }
            if let target = anchored(GuideAnchorID.hrtPlanButton, kind: .hrtPlanButton, cornerRadius: 22) {
                return target
            }
            return GuideTarget(kind: .hrtPlanButton, frame: topRightButtonFrame(in: proxy), cornerRadius: 22)
        case .dailyCheckin:
            if selectedTab != .hrt {
                let frame = tabTargetFrame(.hrt, in: proxy)
                return GuideTarget(kind: .tab(.hrt), frame: frame, cornerRadius: 14)
            }
            if let target = anchored(GuideAnchorID.hrtCheckinButton, kind: .hrtCheckinButton, cornerRadius: 95) {
                return target
            }
            let size: CGFloat = 190
            let yFactor: CGFloat = isPadLayout ? 0.30 : 0.26
            let frame = CGRect(
                x: (proxy.size.width - size) / 2,
                y: proxy.size.height * yFactor,
                width: size,
                height: size
            )
            return GuideTarget(kind: .hrtCheckinButton, frame: frame, cornerRadius: size / 2)
        case .uploadLab:
            if selectedTab != .labs {
                let frame = tabTargetFrame(.labs, in: proxy)
                return GuideTarget(kind: .tab(.labs), frame: frame, cornerRadius: 14)
            }
            if let target = anchored(GuideAnchorID.labsAddButton, kind: .labsAddButton, cornerRadius: 22) {
                return target
            }
            return GuideTarget(kind: .labsAddButton, frame: topRightButtonFrame(in: proxy), cornerRadius: 22)
        case .readInterpretation:
            if selectedTab != .labs {
                let frame = tabTargetFrame(.labs, in: proxy)
                return GuideTarget(kind: .tab(.labs), frame: frame, cornerRadius: 14)
            }
            if let target = anchored(GuideAnchorID.labsFirstReportCard, kind: .labsReportArea, cornerRadius: 12) {
                return target
            }
            let frame = CGRect(
                x: isPadLayout ? 24 : 14,
                y: proxy.safeAreaInsets.top + (isPadLayout ? 140 : 120),
                width: proxy.size.width - (isPadLayout ? 48 : 28),
                height: isPadLayout ? 96 : 86
            )
            return GuideTarget(kind: .labsReportArea, frame: frame, cornerRadius: 12)
        case .briefShare:
            if selectedTab != .brief {
                let frame = tabTargetFrame(.brief, in: proxy)
                return GuideTarget(kind: .tab(.brief), frame: frame, cornerRadius: 14)
            }
            if let target = anchored(GuideAnchorID.briefSection, kind: .briefArea, cornerRadius: 12) {
                return target
            }
            let frame = CGRect(
                x: isPadLayout ? 28 : 18,
                y: proxy.safeAreaInsets.top + (isPadLayout ? 140 : 120),
                width: proxy.size.width - (isPadLayout ? 56 : 36),
                height: isPadLayout ? 132 : 120
            )
            return GuideTarget(kind: .briefArea, frame: frame, cornerRadius: 12)
        }
    }

    private func handleGuideTap(step: GuideStep, target: GuideTargetKind) {
        switch target {
        case .tab(let tab):
            selectedTab = tab
            return
        case .hrtPlanButton:
            NotificationCenter.default.post(name: .guideOpenPlanEditor, object: nil)
        case .hrtCheckinButton:
            NotificationCenter.default.post(name: .guideTriggerCheckin, object: nil)
        case .labsAddButton:
            NotificationCenter.default.post(name: .guideOpenAddReport, object: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                NotificationCenter.default.post(name: .guideLoadSampleOCR, object: nil)
            }
        case .labsReportArea:
            break
        case .briefArea:
            break
        }

        if let next = GuideStep(rawValue: step.rawValue + 1) {
            guideStep = next
        } else {
            hasCompletedInteractiveGuide = true
            guideStep = nil
            interactiveGuideInProgress = false
            cleanupGuideSampleData()
        }
    }

    private func cleanupGuideSampleData() {
        for report in reports where report.isGuideSample {
            if let fileName = report.reportImageFileName,
               let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let fileURL = directory.appendingPathComponent(fileName)
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    try? FileManager.default.removeItem(at: fileURL)
                }
            }
            modelContext.delete(report)
        }
    }

    private func stepTitle(_ step: GuideStep) -> String {
        switch step {
        case .setPlan: return AppLocalization.text("guide.step1.title", lang: appLanguage)
        case .dailyCheckin: return AppLocalization.text("guide.step2.title", lang: appLanguage)
        case .uploadLab: return AppLocalization.text("guide.step3.title", lang: appLanguage)
        case .readInterpretation: return AppLocalization.text("guide.step4.title", lang: appLanguage)
        case .briefShare: return AppLocalization.text("guide.step5.title", lang: appLanguage)
        }
    }

    private func stepDescription(_ step: GuideStep) -> String {
        switch step {
        case .setPlan: return AppLocalization.text("guide.step1.desc", lang: appLanguage)
        case .dailyCheckin: return AppLocalization.text("guide.step2.desc", lang: appLanguage)
        case .uploadLab: return AppLocalization.text("guide.step3.desc", lang: appLanguage)
        case .readInterpretation: return AppLocalization.text("guide.step4.desc", lang: appLanguage)
        case .briefShare: return AppLocalization.text("guide.step5.desc", lang: appLanguage)
        }
    }
}

extension Notification.Name {
    static let guideOpenPlanEditor = Notification.Name("guideOpenPlanEditor")
    static let guideTriggerCheckin = Notification.Name("guideTriggerCheckin")
    static let guideOpenAddReport = Notification.Name("guideOpenAddReport")
    static let guideLoadSampleOCR = Notification.Name("guideLoadSampleOCR")
}

enum GuideAnchorID {
    static let hrtPlanButton = "guide.hrt.plan.button"
    static let hrtCheckinButton = "guide.hrt.checkin.button"
    static let labsAddButton = "guide.labs.add.button"
    static let labsFirstReportCard = "guide.labs.first.report.card"
    static let briefSection = "guide.brief.section"
}

struct GuideAnchorPreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct GuideAnchorModifier: ViewModifier {
    let id: String
    func body(content: Content) -> some View {
        content.background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: GuideAnchorPreferenceKey.self,
                    value: [id: proxy.frame(in: .global)]
                )
            }
        )
    }
}

extension View {
    func guideAnchor(_ id: String) -> some View {
        modifier(GuideAnchorModifier(id: id))
    }
}
