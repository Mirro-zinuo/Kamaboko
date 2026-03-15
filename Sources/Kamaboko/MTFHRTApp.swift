//
//  KamabokoApp.swift
//  Kamaboko
//
//  Created by Mirro on 2/26/26.
//

import SwiftUI
import SwiftData
import Foundation

@main
struct KamabokoApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            HRTDoseEntry.self,
            HRTPlan.self,
            DailyHRTCheckin.self,
            LabReport.self,
            LabEntry.self,
            ReportAttachment.self,
            RLEEntry.self,
        ])
        let storeURL = makeStoreURL()
        let modelConfiguration = ModelConfiguration(
            "default",
            schema: schema,
            url: storeURL,
            allowsSave: true
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            destroyStoreIfNeeded(at: storeURL)
            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer after resetting store: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
private func makeStoreURL() -> URL {
    let baseURL = URL.applicationSupportDirectory
    try? FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
    return baseURL.appendingPathComponent("Kamaboko.store")
}

private func destroyStoreIfNeeded(at storeURL: URL) {
    let fileManager = FileManager.default
    let relatedURLs = [
        storeURL,
        storeURL.appendingPathExtension("shm"),
        storeURL.appendingPathExtension("wal")
    ]

    for url in relatedURLs where fileManager.fileExists(atPath: url.path) {
        try? fileManager.removeItem(at: url)
    }
}
