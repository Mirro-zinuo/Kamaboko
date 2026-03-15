import SwiftUI
import SwiftData

struct AddLabView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var date = Date()
    @State private var type: LabType = .estradiolE2
    @State private var unit: LabUnit = .pmolL
    @State private var valueText = ""
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $date, displayedComponents: .date)

                Picker("Marker", selection: $type) {
                    ForEach(LabType.allCases) { Text($0.displayName).tag($0) }
                }

                TextField("Value", text: $valueText)
                    .keyboardType(.decimalPad)

                Picker("Unit", selection: $unit) {
                    ForEach(LabUnit.allCases) { Text($0.rawValue).tag($0) }
                }

                TextField("Note (optional)", text: $note)
            }
            .navigationTitle("Add Lab")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        guard let v = Double(valueText.replacingOccurrences(of: ",", with: ".")) else { return }
                        let entry = LabEntry(date: date, type: type, value: v, unit: unit, note: note.isEmpty ? nil : note)
                        modelContext.insert(entry)
                        dismiss()
                    }
                    .disabled(Double(valueText.replacingOccurrences(of: ",", with: ".")) == nil)
                }
            }
        }
    }
}
