import SwiftUI

struct MTFWikiLocalResourcesView: View {
    @AppStorage("appLanguage") private var appLanguage = "zh-Hans"
    private let pages = LocalWikiPage.loadBundledPages()

    var body: some View {
        List {
            Section(AppLocalization.text("wiki.section.info", lang: appLanguage)) {
                Text(AppLocalization.text("wiki.info.desc", lang: appLanguage))
                Text(AppLocalization.text("wiki.info.source", lang: appLanguage))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if pages.isEmpty {
                Section(AppLocalization.text("wiki.empty.title", lang: appLanguage)) {
                    Text(AppLocalization.text("wiki.empty.desc", lang: appLanguage))
                        .foregroundStyle(.secondary)
                }
            } else {
                Section(AppLocalization.text("wiki.section.cn", lang: appLanguage)) {
                    ForEach(pages) { page in
                        NavigationLink(page.displayTitle) {
                            MTFWikiLocalMarkdownDetailView(page: page)
                        }
                    }
                }
            }
        }
        .navigationTitle(AppLocalization.text("wiki.title", lang: appLanguage))
    }
}

private struct LocalWikiPage: Identifiable {
    let id = UUID()
    let fileName: String
    let fileURL: URL
    let displayTitle: String
    let markdown: String

    private static let preferredOrder: [String] = [
        "pku3", "xy3", "lz", "zju2", "jnu1", "qlyy", "cn-other"
    ]

    static func loadBundledPages() -> [LocalWikiPage] {
        preferredOrder.compactMap { fileName in
            guard let fileURL = bundledMarkdownURL(for: fileName),
                  let raw = try? String(contentsOf: fileURL, encoding: .utf8) else {
                return nil
            }
            let title = extractFrontMatterTitle(from: raw) ?? fileName
            let body = stripFrontMatter(from: raw)
            return LocalWikiPage(
                fileName: fileName,
                fileURL: fileURL,
                displayTitle: title,
                markdown: body
            )
        }
    }

    private static func bundledMarkdownURL(for fileName: String) -> URL? {
        if let url = Bundle.main.url(forResource: fileName, withExtension: "md", subdirectory: "MTFWikiOfflineMD") {
            return url
        }
        if let url = Bundle.main.url(forResource: fileName, withExtension: "md") {
            return url
        }
        return nil
    }

    private static func stripFrontMatter(from markdown: String) -> String {
        guard markdown.hasPrefix("---\n") else { return markdown }
        let parts = markdown.components(separatedBy: "\n---\n")
        guard parts.count >= 2 else { return markdown }
        return parts.dropFirst().joined(separator: "\n---\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func extractFrontMatterTitle(from markdown: String) -> String? {
        guard markdown.hasPrefix("---\n"),
              let endRange = markdown.range(of: "\n---\n") else {
            return nil
        }
        let header = String(markdown[..<endRange.lowerBound])
        for line in header.split(separator: "\n") {
            let text = line.trimmingCharacters(in: .whitespaces)
            if text.hasPrefix("title:") {
                return text.replacingOccurrences(of: "title:", with: "")
                    .trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: "\"", with: "")
            }
        }
        return nil
    }
}

private struct MTFWikiLocalMarkdownDetailView: View {
    let page: LocalWikiPage
    @AppStorage("appLanguage") private var appLanguage = "zh-Hans"
    @State private var displayText = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(page.displayTitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(AppLocalization.text("wiki.source.short", lang: appLanguage))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()

                Text(displayText)
                    .font(.body)
                    .lineSpacing(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )
                .padding()
        }
        .navigationTitle(page.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            displayText = AppLocalization.text("wiki.loading", lang: appLanguage)
            displayText = render(markdown: page.markdown)
        }
    }

    private func render(markdown: String) -> String {
        let cleaned = clean(markdown: markdown)
        return cleaned
    }

    private func clean(markdown: String) -> String {
        var output = markdown

        // [文本](url) -> 文本（url）
        output = replacing(
            output,
            pattern: #"\[([^\]]+)\]\((https?://[^)]+)\)"#,
            with: "$1（$2）"
        )

        // [文本]({{< ref "..." >}}) -> 文本
        output = replacing(
            output,
            pattern: #"\[([^\]]+)\]\(\{\{<\s*ref\s+"[^"]+"\s*>\}\}\)"#,
            with: "$1"
        )

        // 移除 Hugo shortcodes，例如 {{< doctor-image ... >}} / {{< ref ... >}}
        output = replacing(output, pattern: #"\{\{<[^>]+>\}\}"#, with: "")

        // 去掉少量内联 HTML 标签，避免原样显示
        output = output.replacingOccurrences(of: "<u>", with: "")
        output = output.replacingOccurrences(of: "</u>", with: "")

        // Markdown 标记清理
        output = replacing(output, pattern: #"^#{1,6}\s*"#, with: "", options: [.anchorsMatchLines])
        output = output.replacingOccurrences(of: "**", with: "")
        output = output.replacingOccurrences(of: "__", with: "")
        output = output.replacingOccurrences(of: "*", with: "")

        // 列表和段落增强换行
        output = replacing(output, pattern: #"\n(\d+\.)\s"#, with: "\n\n$1 ", options: [])
        output = replacing(output, pattern: #"\n-\s"#, with: "\n\n- ", options: [])

        // 收敛空行
        output = output.replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func replacing(
        _ text: String,
        pattern: String,
        with replacement: String,
        options: NSRegularExpression.Options = []
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return text
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: replacement)
    }
}
