import Foundation
import SwiftData

enum AdministrationRoute: String, CaseIterable, Identifiable, Codable {
    case oral
    case gel
    case injection

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .oral: return AppLocalization.text("route.oral")
        case .gel: return AppLocalization.text("route.gel")
        case .injection: return AppLocalization.text("route.injection")
        }
    }
}

enum DoseFrequency: String, CaseIterable, Identifiable, Codable {
    case daily
    case weekly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .daily: return String(localized: "frequency.daily")
        case .weekly: return String(localized: "frequency.weekly")
        }
    }
}

enum DoseIntervalUnit: String, CaseIterable, Identifiable, Codable {
    case day
    case week

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .day: return AppLocalization.text("common.day")
        case .week: return AppLocalization.text("common.week")
        }
    }
}

enum LabType: String, CaseIterable, Identifiable, Codable {
    case estradiolE2
    case testosteroneTotal
    case prolactin
    case shbg
    case alt
    case ast

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .estradiolE2: return String(localized: "lab.estradiol_e2")
        case .testosteroneTotal: return String(localized: "lab.total_testosterone")
        case .prolactin: return String(localized: "lab.prolactin_prl")
        case .shbg: return String(localized: "lab.shbg")
        case .alt: return String(localized: "lab.alt")
        case .ast: return String(localized: "lab.ast")
        }
    }
}

enum LabUnit: String, CaseIterable, Identifiable, Codable {
    case pmolL, pgmL, nmolL, ngdL, iuL, mIUml, none
    var id: String { rawValue }
}

enum LabInterpretation: String, CaseIterable, Identifiable, Codable {
    case dualLow
    case dualHigh
    case normal
    case estradiolLow
    case estradiolHigh
    case testosteroneLow
    case testosteroneHigh

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dualLow: return AppLocalization.text("interpretation.dualLow")
        case .dualHigh: return AppLocalization.text("interpretation.dualHigh")
        case .normal: return AppLocalization.text("interpretation.normal")
        case .estradiolLow: return AppLocalization.text("interpretation.estradiolLow")
        case .estradiolHigh: return AppLocalization.text("interpretation.estradiolHigh")
        case .testosteroneLow: return AppLocalization.text("interpretation.testosteroneLow")
        case .testosteroneHigh: return AppLocalization.text("interpretation.testosteroneHigh")
        }
    }
}

enum AdjustmentSuggestion: String, CaseIterable, Identifiable, Codable {
    case adjustEstradiol
    case adjustAntiAndrogen
    case noAdjustment

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .adjustEstradiol: return AppLocalization.text("suggestion.adjustEstradiol")
        case .adjustAntiAndrogen: return AppLocalization.text("suggestion.adjustAntiAndrogen")
        case .noAdjustment: return AppLocalization.text("suggestion.noAdjustment")
        }
    }
}

enum EstradiolUnit: String, CaseIterable, Identifiable, Codable {
    case pmolL = "pmol/L"
    case pgmL = "pg/mL"

    var id: String { rawValue }
}

enum TestosteroneUnit: String, CaseIterable, Identifiable, Codable {
    case ngdL = "ng/dL"
    case nmolL = "nmol/L"

    var id: String { rawValue }
}

enum ProlactinUnit: String, CaseIterable, Identifiable, Codable {
    case ngmL = "ng/mL"
    case mIUmL = "mIU/mL"

    var id: String { rawValue }
}

@Model
final class HRTDoseEntry {
    var date: Date
    var frequencyRaw: String
    var routeRaw: String
    var medicationName: String
    var estrogenDoseMg: Double?
    var antiAndrogenDoseMg: Double?
    var note: String?

    init(
        date: Date,
        frequency: DoseFrequency,
        route: AdministrationRoute,
        medicationName: String,
        estrogenDoseMg: Double? = nil,
        antiAndrogenDoseMg: Double? = nil,
        note: String? = nil
    ) {
        self.date = date
        self.frequencyRaw = frequency.rawValue
        self.routeRaw = route.rawValue
        self.medicationName = medicationName
        self.estrogenDoseMg = estrogenDoseMg
        self.antiAndrogenDoseMg = antiAndrogenDoseMg
        self.note = note
    }

    var frequency: DoseFrequency { DoseFrequency(rawValue: frequencyRaw) ?? .daily }
    var route: AdministrationRoute { AdministrationRoute(rawValue: routeRaw) ?? .oral }
}

@Model
final class HRTPlan {
    var updatedAt: Date
    var frequencyRaw: String
    var routeRaw: String
    var estrogenEveryValue: Int
    var estrogenEveryUnitRaw: String
    var estrogenMedicationName: String
    var estrogenDoseMg: Double?
    var antiAndrogenEveryValue: Int
    var antiAndrogenEveryUnitRaw: String
    var antiAndrogenMedicationName: String?
    var antiAndrogenDoseMg: Double?
    var note: String?

    init(
        updatedAt: Date = .now,
        frequency: DoseFrequency,
        route: AdministrationRoute,
        estrogenEveryValue: Int = 1,
        estrogenEveryUnit: DoseIntervalUnit = .day,
        estrogenMedicationName: String,
        estrogenDoseMg: Double? = nil,
        antiAndrogenEveryValue: Int = 1,
        antiAndrogenEveryUnit: DoseIntervalUnit = .day,
        antiAndrogenMedicationName: String? = nil,
        antiAndrogenDoseMg: Double? = nil,
        note: String? = nil
    ) {
        self.updatedAt = updatedAt
        self.frequencyRaw = frequency.rawValue
        self.routeRaw = route.rawValue
        self.estrogenEveryValue = estrogenEveryValue
        self.estrogenEveryUnitRaw = estrogenEveryUnit.rawValue
        self.estrogenMedicationName = estrogenMedicationName
        self.estrogenDoseMg = estrogenDoseMg
        self.antiAndrogenEveryValue = antiAndrogenEveryValue
        self.antiAndrogenEveryUnitRaw = antiAndrogenEveryUnit.rawValue
        self.antiAndrogenMedicationName = antiAndrogenMedicationName
        self.antiAndrogenDoseMg = antiAndrogenDoseMg
        self.note = note
    }

    var frequency: DoseFrequency { DoseFrequency(rawValue: frequencyRaw) ?? .daily }
    var route: AdministrationRoute { AdministrationRoute(rawValue: routeRaw) ?? .oral }
    var estrogenEveryUnit: DoseIntervalUnit { DoseIntervalUnit(rawValue: estrogenEveryUnitRaw) ?? .day }
    var antiAndrogenEveryUnit: DoseIntervalUnit { DoseIntervalUnit(rawValue: antiAndrogenEveryUnitRaw) ?? .day }

    var estrogenScheduleText: String { AppLocalization.format("plan.freq", estrogenEveryValue, estrogenEveryUnit.displayName) }
    var antiAndrogenScheduleText: String { AppLocalization.format("plan.freq", antiAndrogenEveryValue, antiAndrogenEveryUnit.displayName) }
}

@Model
final class DailyHRTCheckin {
    var date: Date
    var didTakeMedication: Bool
    var note: String?

    init(date: Date, didTakeMedication: Bool, note: String? = nil) {
        self.date = date
        self.didTakeMedication = didTakeMedication
        self.note = note
    }
}

@Model
final class LabReport {
    var date: Date
    var estradiolValue: Double
    var estradiolUnitRaw: String
    var testosteroneValue: Double
    var testosteroneUnitRaw: String
    var prolactinNgmL: Double?
    var prolactinUnitRaw: String
    var shbgNmolL: Double?
    var altUl: Double?
    var astUl: Double?
    var interpretationRaw: String
    var suggestionRaw: String
    var note: String?
    var reportImageFileName: String?
    var isGuideSample: Bool

    init(
        date: Date,
        estradiolValue: Double,
        estradiolUnit: EstradiolUnit,
        testosteroneValue: Double,
        testosteroneUnit: TestosteroneUnit,
        prolactinNgmL: Double? = nil,
        prolactinUnit: ProlactinUnit = .ngmL,
        shbgNmolL: Double? = nil,
        altUl: Double? = nil,
        astUl: Double? = nil,
        interpretation: LabInterpretation,
        suggestion: AdjustmentSuggestion,
        note: String? = nil,
        reportImageFileName: String? = nil,
        isGuideSample: Bool = false
    ) {
        self.date = date
        self.estradiolValue = estradiolValue
        self.estradiolUnitRaw = estradiolUnit.rawValue
        self.testosteroneValue = testosteroneValue
        self.testosteroneUnitRaw = testosteroneUnit.rawValue
        self.prolactinNgmL = prolactinNgmL
        self.prolactinUnitRaw = prolactinUnit.rawValue
        self.shbgNmolL = shbgNmolL
        self.altUl = altUl
        self.astUl = astUl
        self.interpretationRaw = interpretation.rawValue
        self.suggestionRaw = suggestion.rawValue
        self.note = note
        self.reportImageFileName = reportImageFileName
        self.isGuideSample = isGuideSample
    }

    var interpretation: LabInterpretation { LabInterpretation(rawValue: interpretationRaw) ?? .normal }
    var suggestion: AdjustmentSuggestion { AdjustmentSuggestion(rawValue: suggestionRaw) ?? .noAdjustment }
    var estradiolUnit: EstradiolUnit { EstradiolUnit(rawValue: estradiolUnitRaw) ?? .pmolL }
    var testosteroneUnit: TestosteroneUnit { TestosteroneUnit(rawValue: testosteroneUnitRaw) ?? .ngdL }
    var prolactinUnit: ProlactinUnit { ProlactinUnit(rawValue: prolactinUnitRaw) ?? .ngmL }
}

@Model
final class LabEntry {
    var date: Date
    var typeRaw: String
    var value: Double
    var unitRaw: String
    var note: String?

    init(date: Date, type: LabType, value: Double, unit: LabUnit, note: String? = nil) {
        self.date = date
        self.typeRaw = type.rawValue
        self.value = value
        self.unitRaw = unit.rawValue
        self.note = note
    }

    var type: LabType { LabType(rawValue: typeRaw) ?? .estradiolE2 }
    var unit: LabUnit { LabUnit(rawValue: unitRaw) ?? .none }
}
@Model
final class ReportAttachment {
    var importedAt: Date
    var displayName: String
    var localFileName: String

    init(importedAt: Date = .now, displayName: String, localFileName: String) {
        self.importedAt = importedAt
        self.displayName = displayName
        self.localFileName = localFileName
    }
}
