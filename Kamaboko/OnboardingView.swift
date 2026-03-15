import SwiftUI

struct OnboardingView: View {
    @Binding var hasSeenOnboarding: Bool
    @AppStorage("appLanguage") private var appLanguage = "zh-Hans"
    @State private var selection = 0

    var body: some View {
        VStack(spacing: 20) {
            TabView(selection: $selection) {
                OnboardingPage(
                    title: localizedText(zhHans: "欢迎使用鱼板", zhHant: "歡迎使用魚板", en: "Welcome to Kamaboko"),
                    subtitle: localizedText(
                        zhHans: "鱼板是专为跨性别女性设计的荷尔蒙替代治疗辅助工具。\n记录 HRT 打卡、管理化验报告、跟踪调整建议。",
                        zhHant: "魚板專為跨性別女性設計的荷爾蒙替代治療輔助工具。\n記錄 HRT 打卡、管理化驗報告、追蹤調整建議。",
                        en: "Kamaboko is a hormone replacement therapy support tool designed for transgender women.\nTrack HRT check-ins, manage lab reports, and follow adjustment suggestions."
                    ),
                    systemImage: "heart.text.square.fill"
                )
                .tag(0)

                OnboardingPage(
                    title: localizedText(zhHans: "每日打卡", zhHant: "每日打卡", en: "Daily Check-in"),
                    subtitle: localizedText(
                        zhHans: "设置用药计划后，每天点一次按钮完成打卡。",
                        zhHant: "設定用藥計劃後，每天點一次按鈕完成打卡。",
                        en: "After setting your plan, tap once daily to check in."
                    ),
                    systemImage: "checkmark.circle.fill"
                )
                .tag(1)

                OnboardingPage(
                    title: localizedText(zhHans: "OCR 报告识别", zhHant: "OCR 報告識別", en: "OCR Report Scan"),
                    subtitle: localizedText(
                        zhHans: "上传化验单图片，自动识别关键指标并获得报告解读。",
                        zhHant: "上傳化驗單圖片，自動識別關鍵指標並獲得報告解讀。",
                        en: "Upload a lab image to auto-detect key values and get report interpretation."
                    ),
                    systemImage: "doc.text.viewfinder"
                )
                .tag(2)

                OnboardingPage(
                    title: "",
                    subtitle: sloganText,
                    systemImage: "heart.fill"
                )
                .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            HStack(spacing: 12) {
                Button(localizedText(zhHans: "跳过", zhHant: "略過", en: "Skip")) {
                    hasSeenOnboarding = true
                }
                .buttonStyle(.bordered)

                Button(selection == 3
                    ? localizedText(zhHans: "开始使用", zhHant: "開始使用", en: "Get Started")
                    : localizedText(zhHans: "下一步", zhHant: "下一步", en: "Next")
                ) {
                    if selection < 3 {
                        withAnimation(.easeInOut) {
                            selection += 1
                        }
                    } else {
                        hasSeenOnboarding = true
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.bottom, 20)
        }
        .padding(.top, 24)
    }

    private func localizedText(zhHans: String, zhHant: String, en: String) -> String {
        switch appLanguage {
        case "zh-Hant":
            return zhHant
        case "en":
            return en
        default:
            return zhHans
        }
    }

    private var sloganText: String {
        switch appLanguage {
        case "en":
            return "The fact that we are alive is the greatest resistance against malice.\nOur very existence is the greatest resistance against malice."
        case "zh-Hant":
            return "我們活著，就是對惡意最大的反抗。\n我們的存在，就是對惡意最大的反抗。"
        default:
            return "我们活着，就是对恶意最大的反抗。\n我们的存在，就是对恶意最大的反抗。"
        }
    }
}

private struct OnboardingPage: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: systemImage)
                .font(.system(size: 64))
                .foregroundStyle(.pink)
            if !title.isEmpty {
                Text(title)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            Spacer()
        }
    }
}
