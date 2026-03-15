import SwiftUI
import SwiftData
import PhotosUI
import Vision
import UIKit

struct LabsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LabReport.date, order: .reverse) private var reports: [LabReport]
    @AppStorage("appLanguage") private var appLanguage = "zh-Hans"

    @State private var showingAddReport = false

    var body: some View {
        NavigationStack {
            List {
                Section(AppLocalization.text("labs.section.reports", lang: appLanguage)) {
                    if reports.isEmpty {
                        ContentUnavailableView(
                            AppLocalization.text("labs.empty.title", lang: appLanguage),
                            systemImage: "doc.text.magnifyingglass",
                            description: Text(AppLocalization.text("labs.empty.desc", lang: appLanguage))
                        )
                    } else {
                        ForEach(Array(reports.enumerated()), id: \.element.id) { index, report in
                            NavigationLink {
                                LabReportDetailView(report: report)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(report.date, style: .date)
                                            .font(.headline)
                                        Spacer()
                                        Text(report.interpretation.displayName)
                                            .font(.subheadline)
                                    }
                                    Text(report.suggestion.displayName)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                            .overlay {
                                if index == 0 {
                                    Color.clear.guideAnchor(GuideAnchorID.labsFirstReportCard)
                                }
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                modelContext.delete(reports[index])
                            }
                        }
                    }
                }
            }
            .navigationTitle(AppLocalization.text("labs.title", lang: appLanguage))
            .toolbar {
                Button {
                    showingAddReport = true
                } label: {
                    Image(systemName: "plus")
                }
                .guideAnchor(GuideAnchorID.labsAddButton)
            }
            .sheet(isPresented: $showingAddReport) {
                AddLabReportView()
            }
            .onReceive(NotificationCenter.default.publisher(for: .guideOpenAddReport)) { _ in
                showingAddReport = true
            }
        }
    }
}

struct AddLabReportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("appLanguage") private var appLanguage = "zh-Hans"
    @AppStorage("interactiveGuideInProgress") private var interactiveGuideInProgress = false

    @AppStorage("lastLabCheckDate") private var lastLabCheckTimestamp: Double = Date().timeIntervalSince1970

    @State private var date = Date()
    @State private var estradiolText = ""
    @State private var estradiolUnit: EstradiolUnit = .pmolL
    @State private var testosteroneText = ""
    @State private var testosteroneUnit: TestosteroneUnit = .ngdL
    @State private var prolactinText = ""
    @State private var prolactinUnit: ProlactinUnit = .ngmL
    @State private var shbgText = ""
    @State private var altText = ""
    @State private var astText = ""
    @State private var note = ""
    @State private var selectedOCRImageItem: PhotosPickerItem?
    @State private var selectedOCRImageData: Data?
    @State private var ocrStatus = ""
    @State private var recognizedTextPreview = ""
    @State private var isGuideSampleOCRLoaded = false

    private struct OCRToken {
        let text: String
        let bounds: CGRect
    }

    private struct OCRMeasurement {
        let value: Double
        let unit: String?
    }

    private var estradiolValue: Double? { parseDecimal(estradiolText) }
    private var testosteroneValue: Double? { parseDecimal(testosteroneText) }
    private var prolactinValue: Double? { parseDecimal(prolactinText) }
    private var shbgValue: Double? { parseDecimal(shbgText) }
    private var altValue: Double? { parseDecimal(altText) }
    private var astValue: Double? { parseDecimal(astText) }

    private var canEvaluate: Bool {
        estradiolValue != nil && testosteroneValue != nil
    }

    private var interpretation: LabInterpretation {
        guard let e2 = estradiolValue, let t = testosteroneValue else { return .normal }
        let e2Canonical = estradiolCanonicalPmolL(from: e2, unit: estradiolUnit)
        let tCanonical = testosteroneCanonicalNgdL(from: t, unit: testosteroneUnit)
        let e2Low = e2Canonical < 100
        let e2High = e2Canonical > 800
        let tLow = tCanonical < 10
        let tHigh = tCanonical > 50

        if e2Low && tLow { return .dualLow }
        if e2High && tHigh { return .dualHigh }
        if e2Low { return .estradiolLow }
        if e2High { return .estradiolHigh }
        if tLow { return .testosteroneLow }
        if tHigh { return .testosteroneHigh }
        return .normal
    }

    private var suggestion: AdjustmentSuggestion {
        switch interpretation {
        case .estradiolLow, .estradiolHigh, .dualLow:
            return .adjustEstradiol
        case .testosteroneLow, .testosteroneHigh, .dualHigh:
            return .adjustAntiAndrogen
        case .normal:
            return .noAdjustment
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(AppLocalization.text("labs.add.section.ocr", lang: appLanguage)) {
                    PhotosPicker(selection: $selectedOCRImageItem, matching: .images) {
                        Label(AppLocalization.text("labs.add.upload_ocr", lang: appLanguage), systemImage: "photo.badge.magnifyingglass")
                    }
                    if !ocrStatus.isEmpty {
                        Text(ocrStatus)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if !recognizedTextPreview.isEmpty {
                        Text(recognizedTextPreview)
                            .font(.caption)
                            .lineLimit(6)
                            .foregroundStyle(.secondary)
                    }
                }

                Section(AppLocalization.text("labs.add.section.info", lang: appLanguage)) {
                    DatePicker(AppLocalization.text("labs.add.date", lang: appLanguage), selection: $date, displayedComponents: .date)
                    TextField(AppLocalization.text("labs.add.e2", lang: appLanguage), text: $estradiolText)
                        .keyboardType(.decimalPad)
                    Picker(AppLocalization.text("labs.add.e2_unit", lang: appLanguage), selection: $estradiolUnit) {
                        ForEach(EstradiolUnit.allCases) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    TextField(AppLocalization.text("labs.add.t", lang: appLanguage), text: $testosteroneText)
                        .keyboardType(.decimalPad)
                    Picker(AppLocalization.text("labs.add.t_unit", lang: appLanguage), selection: $testosteroneUnit) {
                        ForEach(TestosteroneUnit.allCases) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    TextField(AppLocalization.text("labs.add.prl", lang: appLanguage), text: $prolactinText)
                        .keyboardType(.decimalPad)
                    Picker(AppLocalization.text("labs.add.prl_unit", lang: appLanguage), selection: $prolactinUnit) {
                        ForEach(ProlactinUnit.allCases) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    TextField(AppLocalization.text("labs.add.shbg", lang: appLanguage), text: $shbgText)
                        .keyboardType(.decimalPad)
                    TextField(AppLocalization.text("labs.add.alt", lang: appLanguage), text: $altText)
                        .keyboardType(.decimalPad)
                    TextField(AppLocalization.text("labs.add.ast", lang: appLanguage), text: $astText)
                        .keyboardType(.decimalPad)
                    TextField(AppLocalization.text("labs.add.note", lang: appLanguage), text: $note)
                }

                Section(AppLocalization.text("labs.add.section.preview", lang: appLanguage)) {
                    if canEvaluate {
                        HStack {
                            Text(AppLocalization.text("labs.add.result", lang: appLanguage))
                            Spacer()
                            Text(interpretation.displayName)
                        }
                        HStack {
                            Text(AppLocalization.text("labs.add.suggestion", lang: appLanguage))
                            Spacer()
                            Text(suggestion.displayName)
                        }
                    } else {
                        Text(AppLocalization.text("labs.add.need_e2_t", lang: appLanguage))
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Text(AppLocalization.text("labs.add.disclaimer", lang: appLanguage))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(AppLocalization.text("labs.add.title", lang: appLanguage))
            .onChange(of: selectedOCRImageItem) { _, newItem in
                guard let newItem else { return }
                Task { await runOCR(for: newItem) }
            }
            .onReceive(NotificationCenter.default.publisher(for: .guideLoadSampleOCR)) { _ in
                Task { await loadGuideSampleOCR() }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(AppLocalization.text("labs.add.cancel", lang: appLanguage)) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(AppLocalization.text("labs.add.save", lang: appLanguage)) {
                        saveReport()
                    }
                    .disabled(!canEvaluate)
                }
            }
        }
    }

    private func saveReport() {
        guard let e2 = estradiolValue, let t = testosteroneValue else { return }
        let imageFileName = saveSelectedReportImageIfNeeded()

        let report = LabReport(
            date: date,
            estradiolValue: e2,
            estradiolUnit: estradiolUnit,
            testosteroneValue: t,
            testosteroneUnit: testosteroneUnit,
            prolactinNgmL: prolactinValue,
            prolactinUnit: prolactinUnit,
            shbgNmolL: shbgValue,
            altUl: altValue,
            astUl: astValue,
            interpretation: interpretation,
            suggestion: suggestion,
            note: note.isEmpty ? nil : note,
            reportImageFileName: imageFileName,
            isGuideSample: interactiveGuideInProgress && isGuideSampleOCRLoaded
        )
        modelContext.insert(report)
        lastLabCheckTimestamp = date.timeIntervalSince1970
        dismiss()
    }

    private func parseDecimal(_ value: String) -> Double? {
        let normalized = value.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }

    @MainActor
    private func runOCR(for item: PhotosPickerItem) async {
        ocrStatus = AppLocalization.text("labs.ocr.running", lang: appLanguage)
        recognizedTextPreview = ""
        isGuideSampleOCRLoaded = false
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                ocrStatus = AppLocalization.text("labs.ocr.read_failed", lang: appLanguage)
                return
            }
            try applyOCR(fromData: data)
        } catch {
            ocrStatus = AppLocalization.format("labs.ocr.failed", error.localizedDescription, lang: appLanguage)
        }
    }

    @MainActor
    private func loadGuideSampleOCR() async {
        guard interactiveGuideInProgress else { return }
        do {
            let data = try makeGuideSampleImageData()
            isGuideSampleOCRLoaded = true
            try applyOCR(fromData: data)
        } catch {
            ocrStatus = AppLocalization.format("labs.ocr.failed", error.localizedDescription, lang: appLanguage)
        }
    }

    @MainActor
    private func applyOCR(fromData data: Data) throws {
        selectedOCRImageData = data
        let tokens = try recognizeTokens(from: data)
        let text = tokens.map(\.text).joined(separator: "\n")
        recognizedTextPreview = text
        let filledCount = applyOCRResult(from: text, tokens: tokens)
        let parsedDate = extractReportDate(from: text)
        if let parsedDate {
            date = parsedDate
        }
        if filledCount == 0 {
            if parsedDate != nil {
                ocrStatus = AppLocalization.text("labs.ocr.date_only", lang: appLanguage)
            } else {
                ocrStatus = AppLocalization.text("labs.ocr.none", lang: appLanguage)
            }
        } else {
            if parsedDate != nil {
                ocrStatus = AppLocalization.format("labs.ocr.filled_and_date", filledCount, lang: appLanguage)
            } else {
                ocrStatus = AppLocalization.format("labs.ocr.filled", filledCount, lang: appLanguage)
            }
        }
    }

    private func makeGuideSampleImageData() throws -> Data {
        let size = CGSize(width: 1200, height: 1800)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let title = "激素检查报告 / Hormone Lab Report"
            let body = """
            日期 2026-02-28 09:30
            E2 111.0 pmol/L
            Testosterone 12.6 ng/dL
            PRL 14.2 ng/mL
            SHBG 72.0 nmol/L
            """
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = 10

            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 52, weight: .bold),
                .foregroundColor: UIColor.black
            ]
            let bodyAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 46, weight: .regular),
                .foregroundColor: UIColor.black,
                .paragraphStyle: paragraph
            ]

            title.draw(in: CGRect(x: 70, y: 100, width: size.width - 140, height: 80), withAttributes: titleAttrs)
            body.draw(in: CGRect(x: 70, y: 260, width: size.width - 140, height: 1000), withAttributes: bodyAttrs)
        }
        guard let data = image.jpegData(compressionQuality: 0.95) else {
            throw OCRFailure.invalidImage
        }
        return data
    }

    private func recognizeTokens(from imageData: Data) throws -> [OCRToken] {
        guard let image = UIImage(data: imageData),
              let cgImage = image.cgImage else {
            throw OCRFailure.invalidImage
        }

        var tokens: [OCRToken] = []
        let request = VNRecognizeTextRequest { request, _ in
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
            tokens = observations.compactMap { observation in
                guard let candidate = observation.topCandidates(1).first else { return nil }
                return OCRToken(text: candidate.string, bounds: observation.boundingBox)
            }
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])
        return tokens
    }

    private func applyOCRResult(from text: String, tokens: [OCRToken]) -> Int {
        var filledCount = 0
        if let measurement = extractLabMeasurement(labels: ["E2", "Estradiol", "雌二醇"], from: text, tokens: tokens) {
            estradiolText = formatOCRValue(measurement.value)
            if let unit = measurement.unit, let parsed = EstradiolUnit(rawValue: unit) {
                estradiolUnit = parsed
            }
            filledCount += 1
        }
        if let measurement = extractLabMeasurement(labels: ["Testosterone", "Total T", "TT", "总睾酮", "總睾酮", "睾酮"], from: text, tokens: tokens) {
            testosteroneText = formatOCRValue(measurement.value)
            if let unit = measurement.unit, let parsed = TestosteroneUnit(rawValue: unit) {
                testosteroneUnit = parsed
            }
            filledCount += 1
        }
        if let measurement = extractLabMeasurement(labels: ["PRL", "Prolactin", "催乳素", "泌乳素"], from: text, tokens: tokens) {
            prolactinText = formatOCRValue(measurement.value)
            if let unit = measurement.unit, let parsed = ProlactinUnit(rawValue: unit) {
                prolactinUnit = parsed
            }
            filledCount += 1
        }
        if let measurement = extractLabMeasurement(labels: ["SHBG"], from: text, tokens: tokens) {
            shbgText = formatOCRValue(measurement.value)
            filledCount += 1
        }
        if let measurement = extractLabMeasurement(labels: ["ALT"], from: text, tokens: tokens) {
            altText = formatOCRValue(measurement.value)
            filledCount += 1
        }
        if let measurement = extractLabMeasurement(labels: ["AST"], from: text, tokens: tokens) {
            astText = formatOCRValue(measurement.value)
            filledCount += 1
        }
        return filledCount
    }

    private func extractLabMeasurement(labels: [String], from text: String, tokens: [OCRToken]) -> OCRMeasurement? {
        if let tokenBased = extractMeasurementFromTokens(labels: labels, tokens: tokens) {
            return tokenBased
        }
        if let textBasedValue = extractLabValue(labels: labels, from: text) {
            return OCRMeasurement(value: textBasedValue, unit: nil)
        }
        return nil
    }

    private func extractMeasurementFromTokens(labels: [String], tokens: [OCRToken]) -> OCRMeasurement? {
        let labelTokens = tokens.filter { token in
            let lower = token.text.lowercased()
            return labels.contains(where: { lower.contains($0.lowercased()) })
        }

        for labelToken in labelTokens {
            let labelY = labelToken.bounds.midY
            let labelX = labelToken.bounds.maxX

            let valueCandidates = tokens.compactMap { token -> (token: OCRToken, value: Double)? in
                guard token.bounds.minX > labelX else { return nil }
                guard abs(token.bounds.midY - labelY) < 0.06 else { return nil }
                guard let value = firstNumber(in: token.text), value > 0 else { return nil }
                return (token, value)
            }
            .sorted { lhs, rhs in
                lhs.token.bounds.minX < rhs.token.bounds.minX
            }

            if let candidate = valueCandidates.first {
                let unit = extractNearbyUnit(for: candidate.token, tokens: tokens)
                return OCRMeasurement(value: candidate.value, unit: unit)
            }
        }

        return nil
    }

    private func extractNearbyUnit(for valueToken: OCRToken, tokens: [OCRToken]) -> String? {
        let sameRowTokens = tokens
            .filter {
                $0.bounds.minX > valueToken.bounds.maxX &&
                abs($0.bounds.midY - valueToken.bounds.midY) < 0.05
            }
            .sorted { $0.bounds.minX < $1.bounds.minX }

        for token in sameRowTokens {
            if let unit = detectUnit(in: token.text) {
                return unit
            }
        }
        return detectUnit(in: valueToken.text)
    }

    private func detectUnit(in text: String) -> String? {
        let normalized = text.lowercased().replacingOccurrences(of: " ", with: "")
        if normalized.contains("pmol/l") { return "pmol/L" }
        if normalized.contains("pg/ml") { return "pg/mL" }
        if normalized.contains("nmol/l") { return "nmol/L" }
        if normalized.contains("ng/dl") { return "ng/dL" }
        if normalized.contains("ng/ml") { return "ng/mL" }
        if normalized.contains("miu/ml") { return "mIU/mL" }
        if normalized.contains("u/l") { return "U/L" }
        return nil
    }

    private func estradiolCanonicalPmolL(from value: Double, unit: EstradiolUnit) -> Double {
        switch unit {
        case .pmolL:
            return value
        case .pgmL:
            return value * 3.671
        }
    }

    private func testosteroneCanonicalNgdL(from value: Double, unit: TestosteroneUnit) -> Double {
        switch unit {
        case .ngdL:
            return value
        case .nmolL:
            return value * 28.84
        }
    }

    private func extractLabValue(labels: [String], from text: String) -> Double? {
        let lines = text.components(separatedBy: .newlines)
        for (index, line) in lines.enumerated() {
            let lowercasedLine = line.lowercased()
            let matched = labels.contains { lowercasedLine.contains($0.lowercased()) }
            guard matched else { continue }

            if let value = numberAfterLabel(in: line, labels: labels) {
                return value
            }

            if let value = lastNumber(in: line) {
                return value
            }

            if index + 1 < lines.count, let value = firstNumber(in: lines[index + 1]) {
                return value
            }
        }
        return nil
    }

    private func numberAfterLabel(in line: String, labels: [String]) -> Double? {
        let escapedLabels = labels.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
        let pattern = "(?i)(?:\(escapedLabels))\\s*[:：=]?\\s*([0-9]+(?:[.,][0-9]+)?)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, range: range),
              let numberRange = Range(match.range(at: 1), in: line) else {
            return nil
        }
        let numberText = String(line[numberRange]).replacingOccurrences(of: ",", with: ".")
        return Double(numberText)
    }

    private func lastNumber(in text: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: #"([0-9]+(?:[.,][0-9]+)?)"#) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, range: range)
        guard let last = matches.last,
              let numberRange = Range(last.range(at: 1), in: text) else {
            return nil
        }
        let numberText = String(text[numberRange]).replacingOccurrences(of: ",", with: ".")
        return Double(numberText)
    }

    private func firstNumber(in text: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: #"([0-9]+(?:[.,][0-9]+)?)"#) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let numberRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        let numberText = String(text[numberRange]).replacingOccurrences(of: ",", with: ".")
        return Double(numberText)
    }

    private func formatOCRValue(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(value)
    }

    private func extractReportDate(from text: String) -> Date? {
        let patterns = [
            #"(20\d{2}[-/.年]\d{1,2}[-/.月]\d{1,2}(?:[日\sT]\s*\d{1,2}[:：]\d{1,2}(?::\d{1,2})?)?)"#,
            #"(20\d{2}[-/.]\d{1,2}[-/.]\d{1,2})"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
            guard let match = regex.firstMatch(in: text, range: nsRange),
                  let range = Range(match.range(at: 1), in: text) else { continue }

            let rawDate = String(text[range])
            if let date = parseDateString(rawDate) {
                return date
            }
        }
        return nil
    }

    private func parseDateString(_ raw: String) -> Date? {
        let normalized = raw
            .replacingOccurrences(of: "年", with: "-")
            .replacingOccurrences(of: "月", with: "-")
            .replacingOccurrences(of: "日", with: "")
            .replacingOccurrences(of: "：", with: ":")
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ".", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let formats = [
            "yyyy-M-d HH:mm:ss",
            "yyyy-M-d HH:mm",
            "yyyy-M-d"
        ]

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: normalized) {
                return date
            }
        }

        return nil
    }

    private func saveSelectedReportImageIfNeeded() -> String? {
        guard let imageData = selectedOCRImageData else { return nil }
        guard let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }

        let fileName = "\(UUID().uuidString).jpg"
        let fileURL = directory.appendingPathComponent(fileName)
        do {
            try imageData.write(to: fileURL, options: .atomic)
            return fileName
        } catch {
            return nil
        }
    }
}

private enum OCRFailure: Error {
    case invalidImage
}

struct LabReportDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLanguage") private var appLanguage = "zh-Hans"
    let report: LabReport
    @State private var showingDeleteAlert = false

    var body: some View {
        Form {
            Section(AppLocalization.text("labs.detail.results", lang: appLanguage)) {
                Text("E2: \(report.estradiolValue, specifier: "%.1f") \(report.estradiolUnit.rawValue)")
                Text("T: \(report.testosteroneValue, specifier: "%.1f") \(report.testosteroneUnit.rawValue)")
                if let prolactinNgmL = report.prolactinNgmL {
                    Text("PRL: \(prolactinNgmL, specifier: "%.1f") \(report.prolactinUnit.rawValue)")
                }
                if let shbgNmolL = report.shbgNmolL {
                    Text("SHBG: \(shbgNmolL, specifier: "%.1f") nmol/L")
                }
                if let altUl = report.altUl {
                    Text("ALT: \(altUl, specifier: "%.1f") U/L")
                }
                if let astUl = report.astUl {
                    Text("AST: \(astUl, specifier: "%.1f") U/L")
                }
                Text(report.date, style: .date)
            }

            Section(AppLocalization.text("labs.detail.interpretation", lang: appLanguage)) {
                Text(report.interpretation.displayName)
                Text(report.suggestion.displayName)
            }

            if let note = report.note, !note.isEmpty {
                Section(AppLocalization.text("labs.detail.note", lang: appLanguage)) {
                    Text(note)
                }
            }

            if let image = loadReportImage() {
                Section(AppLocalization.text("labs.detail.image", lang: appLanguage)) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .navigationTitle(AppLocalization.text("labs.detail.title", lang: appLanguage))
        .toolbar {
            Button(role: .destructive) {
                showingDeleteAlert = true
            } label: {
                Image(systemName: "trash")
            }
        }
        .alert(AppLocalization.text("labs.detail.delete_confirm_title", lang: appLanguage), isPresented: $showingDeleteAlert) {
            Button(AppLocalization.text("labs.detail.delete", lang: appLanguage), role: .destructive) {
                deleteReport()
            }
            Button(AppLocalization.text("labs.add.cancel", lang: appLanguage), role: .cancel) { }
        } message: {
            Text(AppLocalization.text("labs.detail.cannot_undo", lang: appLanguage))
        }
    }

    private func loadReportImage() -> UIImage? {
        guard let fileName = report.reportImageFileName else { return nil }
        guard let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let url = directory.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    private func deleteReport() {
        if let fileName = report.reportImageFileName,
           let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = directory.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
        modelContext.delete(report)
        dismiss()
    }
}
