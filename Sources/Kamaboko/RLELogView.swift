import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct RLELogView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RLEEntry.date, order: .reverse) private var entries: [RLEEntry]
    @AppStorage("appLanguage") private var appLanguage = "zh-Hans"

    @State private var showingAddEntry = false

    var body: some View {
        NavigationStack {
            List {
                if entries.isEmpty {
                    ContentUnavailableView(
                        AppLocalization.text("rle.empty.title", lang: appLanguage),
                        systemImage: "sparkles",
                        description: Text(AppLocalization.text("rle.empty.desc", lang: appLanguage))
                    )
                } else {
                    ForEach(entries) { entry in
                        NavigationLink {
                            RLEDetailView(entry: entry)
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                if let thumb = loadEntryThumbnail(for: entry) {
                                    Image(uiImage: thumb)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 52, height: 52)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(entry.date, style: .date)
                                            .font(.headline)
                                        Spacer()
                                    }
                                    if let aiSupport = entry.aiSupport, !aiSupport.isEmpty {
                                        Text(aiSupport)
                                            .font(.caption)
                                            .lineLimit(2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let entry = entries[index]
                            deleteEntryImageIfNeeded(entry)
                            modelContext.delete(entry)
                        }
                    }
                }
            }
            .navigationTitle(AppLocalization.text("rle.title", lang: appLanguage))
            .toolbar {
                Button {
                    showingAddEntry = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showingAddEntry) {
                AddRLEEntryView()
            }
        }
    }

    private func loadEntryThumbnail(for entry: RLEEntry) -> UIImage? {
        guard let fileName = entry.imageFileName else { return nil }
        guard let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let url = directory.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else { return nil }
        return image
    }

    private func deleteEntryImageIfNeeded(_ entry: RLEEntry) {
        guard let fileName = entry.imageFileName else { return }
        guard let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        let url = directory.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

struct AddRLEEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("appLanguage") private var appLanguage = "zh-Hans"
    @AppStorage("xaiApiKey") private var xaiApiKey = ""
    @AppStorage("xaiBaseURL") private var xaiBaseURL = "https://api.x.ai"
    @AppStorage("xaiModel") private var xaiModel = "grok-4-fast"

    @Query(sort: \RLEEntry.date, order: .reverse) private var entries: [RLEEntry]

    @State private var date = Date()
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    @State private var statusMessage = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section(AppLocalization.text("rle.add.section.main", lang: appLanguage)) {
                    DatePicker(AppLocalization.text("rle.add.date", lang: appLanguage), selection: $date, displayedComponents: .date)
                }

                Section(AppLocalization.text("rle.add.section.photo", lang: appLanguage)) {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label(AppLocalization.text("rle.add.photo", lang: appLanguage), systemImage: "photo")
                    }
                    if let selectedPhotoData, let image = UIImage(data: selectedPhotoData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    Text(AppLocalization.text("rle.add.photo.help", lang: appLanguage))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if !statusMessage.isEmpty {
                    Section {
                        Text(statusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button(AppLocalization.text("rle.add.save", lang: appLanguage)) {
                        saveEntry(useAI: false)
                    }
                    .disabled(!canSave || isSaving)

                    Button(AppLocalization.text("rle.add.save_ai", lang: appLanguage)) {
                        Task { await saveEntry(useAI: true) }
                    }
                    .disabled(!canSave || isSaving)
                }
            }
            .navigationTitle(AppLocalization.text("rle.add.title", lang: appLanguage))
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else { return }
                Task { await loadSelectedPhoto(from: newItem) }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(AppLocalization.text("rle.add.cancel", lang: appLanguage)) { dismiss() }
                }
            }
        }
    }

    private var canSave: Bool {
        selectedPhotoData != nil
    }

    @MainActor
    private func saveEntry(useAI: Bool) async {
        isSaving = true
        defer { isSaving = false }

        guard let imageFileName = saveSelectedPhotoIfNeeded() else {
            statusMessage = AppLocalization.text("rle.add.photo.required", lang: appLanguage)
            return
        }

        let entry = RLEEntry(
            date: date,
            imageFileName: imageFileName
        )
        modelContext.insert(entry)

        guard useAI else {
            dismiss()
            return
        }

        guard !xaiApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            statusMessage = AppLocalization.text("rle.ai.missing_key", lang: appLanguage)
            return
        }
        guard !xaiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            statusMessage = AppLocalization.text("rle.ai.missing_url", lang: appLanguage)
            return
        }

        statusMessage = AppLocalization.text("rle.ai.generating", lang: appLanguage)
        do {
            let currentImageDataURL = try imageDataURL(for: imageFileName)
            let previousImageURL = latestPreviousImageDataURL(excluding: entry)
            let historyImageURLs = historyImageDataURLs(excluding: entry, excludingPrevious: previousImageURL)

            let support = try await XAIChatClient.generateRLESupportWithImages(
                entry: entry,
                languageCode: appLanguage,
                apiKey: xaiApiKey,
                baseURL: xaiBaseURL,
                model: xaiModel,
                currentImageDataURL: currentImageDataURL,
                previousImageDataURL: previousImageURL,
                historyImageDataURLs: historyImageURLs
            )
            entry.aiSupport = support
            entry.aiGeneratedAt = .now
            statusMessage = ""
            dismiss()
        } catch {
            statusMessage = AppLocalization.format("rle.ai.failed", error.localizedDescription, lang: appLanguage)
        }
    }

    private func saveEntry(useAI: Bool) {
        Task { await saveEntry(useAI: useAI) }
    }

    @MainActor
    private func loadSelectedPhoto(from item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        selectedPhotoData = data
    }

    private func saveSelectedPhotoIfNeeded() -> String? {
        guard let data = selectedPhotoData,
              let image = UIImage(data: data),
              let processed = resizedJPEGData(from: image, maxDimension: 1280) else {
            return nil
        }
        guard let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }

        let fileName = "\(UUID().uuidString).jpg"
        let fileURL = directory.appendingPathComponent(fileName)
        do {
            try processed.write(to: fileURL, options: .atomic)
            return fileName
        } catch {
            return nil
        }
    }

    private func resizedJPEGData(from image: UIImage, maxDimension: CGFloat) -> Data? {
        let size = image.size
        let maxSide = max(size.width, size.height)
        let scale = maxSide > maxDimension ? maxDimension / maxSide : 1
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return rendered.jpegData(compressionQuality: 0.82)
    }

    private func imageDataURL(for fileName: String?) throws -> String {
        guard let fileName else { throw XAIChatClient.APIError(message: "Missing photo") }
        guard let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw XAIChatClient.APIError(message: "Missing documents directory")
        }
        let url = directory.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url) else {
            throw XAIChatClient.APIError(message: "Unable to read photo")
        }
        let base64 = data.base64EncodedString()
        return "data:image/jpeg;base64,\(base64)"
    }

    private func latestPreviousImageDataURL(excluding entry: RLEEntry) -> String? {
        let previous = entries.first { $0.id != entry.id && $0.imageFileName != nil }
        return (try? imageDataURL(for: previous?.imageFileName))
    }

    private func historyImageDataURLs(excluding entry: RLEEntry, excludingPrevious previousURL: String?) -> [String] {
        let previousFileName = previousURL.flatMap { _ in
            entries.first { $0.id != entry.id && $0.imageFileName != nil }?.imageFileName
        }

        var urls: [String] = []
        for candidate in entries.reversed() where candidate.id != entry.id {
            guard let fileName = candidate.imageFileName else { continue }
            if let previousFileName, fileName == previousFileName { continue }
            if let url = try? imageDataURL(for: fileName) {
                urls.append(url)
            }
        }
        return urls
    }
}

struct RLEDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLanguage") private var appLanguage = "zh-Hans"

    let entry: RLEEntry
    @State private var showingDeleteAlert = false

    var body: some View {
        Form {
            Section(AppLocalization.text("rle.detail.section.main", lang: appLanguage)) {
                Text(entry.date, style: .date)
            }

            if let image = loadEntryImage() {
                Section(AppLocalization.text("rle.detail.section.photo", lang: appLanguage)) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            if let aiSupport = entry.aiSupport, !aiSupport.isEmpty {
                Section(AppLocalization.text("rle.detail.section.ai", lang: appLanguage)) {
                    Text(aiSupport)
                }
            }
        }
        .navigationTitle(AppLocalization.text("rle.detail.title", lang: appLanguage))
        .toolbar {
            Button(role: .destructive) {
                showingDeleteAlert = true
            } label: {
                Image(systemName: "trash")
            }
        }
        .alert(AppLocalization.text("rle.detail.delete_confirm_title", lang: appLanguage), isPresented: $showingDeleteAlert) {
            Button(AppLocalization.text("rle.detail.delete", lang: appLanguage), role: .destructive) {
                deleteEntry()
            }
            Button(AppLocalization.text("common.cancel", lang: appLanguage), role: .cancel) { }
        } message: {
            Text(AppLocalization.text("rle.detail.cannot_undo", lang: appLanguage))
        }
    }

    private func loadEntryImage() -> UIImage? {
        guard let fileName = entry.imageFileName else { return nil }
        guard let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let url = directory.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    private func deleteEntry() {
        if let fileName = entry.imageFileName,
           let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let url = directory.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: url.path) {
                try? FileManager.default.removeItem(at: url)
            }
        }
        modelContext.delete(entry)
        dismiss()
    }
}
