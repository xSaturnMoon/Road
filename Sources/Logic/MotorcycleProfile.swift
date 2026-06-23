import Foundation
import SwiftUI
import MapKit

enum EngineStroke: String, CaseIterable, Codable, Identifiable {
    case twoStroke = "2 tempi"
    case fourStroke = "4 tempi"

    var id: String { rawValue }

    var consumptionFactor: Double {
        switch self {
        case .twoStroke: return 1.18
        case .fourStroke: return 1.0
        }
    }
}

enum MotorcycleClass: String {
    case scooter
    case maxiScooter
    case naked
    case sport
    case touring
    case enduro

    var consumptionMultiplier: Double {
        switch self {
        case .scooter: return 0.92
        case .maxiScooter: return 1.0
        case .naked: return 1.05
        case .sport: return 1.12
        case .touring: return 1.08
        case .enduro: return 1.02
        }
    }
}

struct MotorcyclePreset: Identifiable, Hashable {
    let id: String
    let brand: String
    let model: String
    let displacementCC: Int
    let stroke: EngineStroke
    let vehicleClass: MotorcycleClass
    let fuelConsumptionL100: Double
    let travelTimeFactor: Double

    var displayName: String { "\(brand) \(model)" }
}

enum MotorcyclePresets {
    static let customID = "custom"

    static let all: [MotorcyclePreset] = [
        MotorcyclePreset(id: "honda-sh125", brand: "Honda", model: "SH 125", displacementCC: 125, stroke: .fourStroke, vehicleClass: .scooter, fuelConsumptionL100: 2.9, travelTimeFactor: 1.06),
        MotorcyclePreset(id: "honda-sh150", brand: "Honda", model: "SH 150", displacementCC: 150, stroke: .fourStroke, vehicleClass: .scooter, fuelConsumptionL100: 3.1, travelTimeFactor: 1.04),
        MotorcyclePreset(id: "honda-forza125", brand: "Honda", model: "Forza 125", displacementCC: 125, stroke: .fourStroke, vehicleClass: .maxiScooter, fuelConsumptionL100: 3.2, travelTimeFactor: 1.05),
        MotorcyclePreset(id: "honda-cb125", brand: "Honda", model: "CB 125", displacementCC: 125, stroke: .fourStroke, vehicleClass: .naked, fuelConsumptionL100: 3.6, travelTimeFactor: 1.03),
        MotorcyclePreset(id: "honda-cb500", brand: "Honda", model: "CB 500", displacementCC: 471, stroke: .fourStroke, vehicleClass: .naked, fuelConsumptionL100: 4.6, travelTimeFactor: 0.96),
        MotorcyclePreset(id: "piaggio-liberty125", brand: "Piaggio", model: "Liberty 125", displacementCC: 125, stroke: .fourStroke, vehicleClass: .scooter, fuelConsumptionL100: 2.8, travelTimeFactor: 1.07),
        MotorcyclePreset(id: "piaggio-beverly300", brand: "Piaggio", model: "Beverly 300", displacementCC: 300, stroke: .fourStroke, vehicleClass: .maxiScooter, fuelConsumptionL100: 3.8, travelTimeFactor: 1.0),
        MotorcyclePreset(id: "vespa-primavera125", brand: "Vespa", model: "Primavera 125", displacementCC: 125, stroke: .fourStroke, vehicleClass: .scooter, fuelConsumptionL100: 3.0, travelTimeFactor: 1.06),
        MotorcyclePreset(id: "vespa-gts300", brand: "Vespa", model: "GTS 300", displacementCC: 300, stroke: .fourStroke, vehicleClass: .maxiScooter, fuelConsumptionL100: 3.7, travelTimeFactor: 1.0),
        MotorcyclePreset(id: "yamaha-nmax125", brand: "Yamaha", model: "NMAX 125", displacementCC: 125, stroke: .fourStroke, vehicleClass: .scooter, fuelConsumptionL100: 2.8, travelTimeFactor: 1.05),
        MotorcyclePreset(id: "yamaha-xmax300", brand: "Yamaha", model: "XMAX 300", displacementCC: 292, stroke: .fourStroke, vehicleClass: .maxiScooter, fuelConsumptionL100: 3.9, travelTimeFactor: 0.99),
        MotorcyclePreset(id: "yamaha-mt125", brand: "Yamaha", model: "MT-125", displacementCC: 125, stroke: .fourStroke, vehicleClass: .naked, fuelConsumptionL100: 3.7, travelTimeFactor: 1.02),
        MotorcyclePreset(id: "yamaha-tracer7", brand: "Yamaha", model: "Tracer 7", displacementCC: 689, stroke: .fourStroke, vehicleClass: .touring, fuelConsumptionL100: 5.2, travelTimeFactor: 0.94),
        MotorcyclePreset(id: "aprilia-srgt125", brand: "Aprilia", model: "SR GT 125", displacementCC: 125, stroke: .fourStroke, vehicleClass: .maxiScooter, fuelConsumptionL100: 3.1, travelTimeFactor: 1.05),
        MotorcyclePreset(id: "aprilia-rs125", brand: "Aprilia", model: "RS 125", displacementCC: 125, stroke: .fourStroke, vehicleClass: .sport, fuelConsumptionL100: 4.1, travelTimeFactor: 1.0),
        MotorcyclePreset(id: "ktm-duke125", brand: "KTM", model: "Duke 125", displacementCC: 125, stroke: .fourStroke, vehicleClass: .naked, fuelConsumptionL100: 3.9, travelTimeFactor: 1.01),
        MotorcyclePreset(id: "ktm-duke390", brand: "KTM", model: "Duke 390", displacementCC: 373, stroke: .fourStroke, vehicleClass: .naked, fuelConsumptionL100: 4.3, travelTimeFactor: 0.97),
        MotorcyclePreset(id: "bmw-g310r", brand: "BMW", model: "G 310 R", displacementCC: 313, stroke: .fourStroke, vehicleClass: .naked, fuelConsumptionL100: 4.0, travelTimeFactor: 0.98),
        MotorcyclePreset(id: "bmw-r1250gs", brand: "BMW", model: "R 1250 GS", displacementCC: 1254, stroke: .fourStroke, vehicleClass: .touring, fuelConsumptionL100: 5.6, travelTimeFactor: 0.93),
        MotorcyclePreset(id: "ducati-monster937", brand: "Ducati", model: "Monster", displacementCC: 937, stroke: .fourStroke, vehicleClass: .naked, fuelConsumptionL100: 5.8, travelTimeFactor: 0.92),
        MotorcyclePreset(id: "fantic-caballero125", brand: "Fantic", model: "Caballero 125", displacementCC: 125, stroke: .fourStroke, vehicleClass: .enduro, fuelConsumptionL100: 3.4, travelTimeFactor: 1.03),
        MotorcyclePreset(id: "fantic-performance125", brand: "Fantic", model: "Performance 125", displacementCC: 125, stroke: .fourStroke, vehicleClass: .enduro, fuelConsumptionL100: 3.5, travelTimeFactor: 1.02),
        MotorcyclePreset(id: "fantic-xef125", brand: "Fantic", model: "XEF 125", displacementCC: 125, stroke: .fourStroke, vehicleClass: .enduro, fuelConsumptionL100: 3.5, travelTimeFactor: 1.03),
        MotorcyclePreset(id: "fantic-xmf125", brand: "Fantic", model: "XMF 125", displacementCC: 125, stroke: .fourStroke, vehicleClass: .enduro, fuelConsumptionL100: 3.5, travelTimeFactor: 1.02),
        MotorcyclePreset(id: "fantic-tracker125", brand: "Fantic", model: "Tracker 125", displacementCC: 125, stroke: .fourStroke, vehicleClass: .enduro, fuelConsumptionL100: 3.4, travelTimeFactor: 1.03),
        MotorcyclePreset(id: "fantic-issimo125", brand: "Fantic", model: "Issimo 125", displacementCC: 125, stroke: .fourStroke, vehicleClass: .scooter, fuelConsumptionL100: 2.9, travelTimeFactor: 1.06),
        MotorcyclePreset(id: "fantic-casa50", brand: "Fantic", model: "Casa 50", displacementCC: 50, stroke: .twoStroke, vehicleClass: .scooter, fuelConsumptionL100: 2.6, travelTimeFactor: 1.11),
        MotorcyclePreset(id: "fantic-xxf250", brand: "Fantic", model: "XXF 250", displacementCC: 250, stroke: .fourStroke, vehicleClass: .enduro, fuelConsumptionL100: 4.0, travelTimeFactor: 1.0),
        MotorcyclePreset(id: "fantic-xef250", brand: "Fantic", model: "XEF 250", displacementCC: 250, stroke: .fourStroke, vehicleClass: .enduro, fuelConsumptionL100: 4.1, travelTimeFactor: 0.99),
        MotorcyclePreset(id: "fantic-xxf450", brand: "Fantic", model: "XXF 450", displacementCC: 450, stroke: .fourStroke, vehicleClass: .enduro, fuelConsumptionL100: 4.8, travelTimeFactor: 0.96),
        MotorcyclePreset(id: "generic-50", brand: "Generica", model: "50cc", displacementCC: 50, stroke: .twoStroke, vehicleClass: .scooter, fuelConsumptionL100: 2.5, travelTimeFactor: 1.12),
        MotorcyclePreset(id: "generic-125", brand: "Generica", model: "125cc", displacementCC: 125, stroke: .fourStroke, vehicleClass: .scooter, fuelConsumptionL100: 3.2, travelTimeFactor: 1.05),
        MotorcyclePreset(id: "generic-300", brand: "Generica", model: "300cc", displacementCC: 300, stroke: .fourStroke, vehicleClass: .maxiScooter, fuelConsumptionL100: 3.9, travelTimeFactor: 1.0),
    ]

    static func preset(id: String) -> MotorcyclePreset? {
        all.first { $0.id == id }
    }

    static var brands: [String] {
        Array(Set(all.map(\.brand))).sorted()
    }

    static func models(for brand: String) -> [MotorcyclePreset] {
        all.filter { $0.brand == brand }
    }
}

@MainActor
final class MotorcycleStore: ObservableObject {
    static let shared = MotorcycleStore()

    @AppStorage("moto_preset_id") var presetID: String = "generic-125"
    @AppStorage("moto_brand") var brand: String = ""
    @AppStorage("moto_model") var model: String = ""
    @AppStorage("moto_displacement") var displacementCC: Int = 125
    @AppStorage("moto_stroke") private var strokeRaw: String = EngineStroke.fourStroke.rawValue
    @AppStorage("moto_custom_consumption") var customConsumptionL100: Double = 0

    var stroke: EngineStroke {
        get { EngineStroke(rawValue: strokeRaw) ?? .fourStroke }
        set { strokeRaw = newValue.rawValue; objectWillChange.send() }
    }

    var selectedPreset: MotorcyclePreset? {
        MotorcyclePresets.preset(id: presetID)
    }

    var isCustom: Bool {
        presetID == MotorcyclePresets.customID
    }

    var displayName: String {
        if let preset = selectedPreset, !isCustom {
            return preset.displayName
        }
        let b = brand.trimmingCharacters(in: .whitespaces)
        let m = model.trimmingCharacters(in: .whitespaces)
        if b.isEmpty && m.isEmpty { return "125cc generica" }
        if m.isEmpty { return b }
        if b.isEmpty { return m }
        return "\(b) \(m)"
    }

    var fuelConsumptionL100: Double {
        if customConsumptionL100 > 0 { return customConsumptionL100 }
        if let preset = selectedPreset, !isCustom { return preset.fuelConsumptionL100 }
        return estimatedConsumption(displacementCC: displacementCC, stroke: stroke, vehicleClass: .scooter)
    }

    var travelTimeFactor: Double {
        if let preset = selectedPreset, !isCustom { return preset.travelTimeFactor }
        return estimatedTravelFactor(displacementCC: displacementCC)
    }

    func applyPreset(_ preset: MotorcyclePreset) {
        presetID = preset.id
        brand = preset.brand
        model = preset.model
        displacementCC = preset.displacementCC
        stroke = preset.stroke
        customConsumptionL100 = 0
        objectWillChange.send()
    }

    func useCustomProfile() {
        presetID = MotorcyclePresets.customID
        customConsumptionL100 = 0
        objectWillChange.send()
    }

    func fuelLiters(forDistanceKm distanceKm: Double) -> Double {
        let liters = distanceKm * fuelConsumptionL100 / 100
        return max(liters, distanceKm > 0 ? 0.05 : 0)
    }

    func fuelLiters(forRoute route: MKRoute) -> Double {
        let base = fuelConsumptionL100
        var total = 0.0

        for step in route.steps where step.distance > 20 {
            let distKm = step.distance / 1000
            let context = RoutePlanner.drivingContext(for: step, route: route)
            total += distKm * base * context.consumptionMultiplier / 100
        }

        if total <= 0 {
            return fuelLiters(forDistanceKm: route.distance / 1000)
        }
        return max(total, 0.05)
    }

    func travelMinutes(baseAutomobileMinutes: Int) -> Int {
        max(1, Int((Double(baseAutomobileMinutes) * travelTimeFactor).rounded()))
    }

    private func estimatedConsumption(displacementCC: Int, stroke: EngineStroke, vehicleClass: MotorcycleClass) -> Double {
        let base: Double
        switch displacementCC {
        case ..<80: base = 2.4
        case 80..<126: base = 3.1
        case 126..<251: base = 3.8
        case 251..<401: base = 4.2
        case 401..<751: base = 4.9
        default: base = 5.5
        }
        let value = base * stroke.consumptionFactor * vehicleClass.consumptionMultiplier
        return (value * 10).rounded() / 10
    }

    private func estimatedTravelFactor(displacementCC: Int) -> Double {
        switch displacementCC {
        case ..<80: return 1.12
        case 80..<126: return 1.06
        case 126..<251: return 1.02
        case 251..<401: return 0.98
        case 401..<751: return 0.95
        default: return 0.92
        }
    }

    private init() {
        if brand.isEmpty, !isCustom, let preset = selectedPreset {
            brand = preset.brand
            model = preset.model
            displacementCC = preset.displacementCC
            strokeRaw = preset.stroke.rawValue
        }
    }
}
