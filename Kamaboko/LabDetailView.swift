import SwiftUI

struct LabDetailView: View {
    let lab: LabEntry

    var body: some View {
        Form {
            Section("Result") {
                Text(lab.type.displayName)
                Text("\(lab.value, specifier: "%.2f") \(lab.unit.rawValue)")
                Text(lab.date, style: .date)
            }
            if let note = lab.note, !note.isEmpty {
                Section("Note") { Text(note) }
            }
            Section {
                Text("⚠️ This app is offline and does not provide medical or dosing advice. It helps organize data for clinician discussion.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Detail")
    }
}
