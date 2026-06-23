import Foundation
import MapKit
import SwiftUI

struct TrafficSegment: Identifiable {
    let id = UUID()
    let coordinates: [CLLocationCoordinate2D]
    let level: TrafficLevel
}

enum TrafficLevel {
    case free
    case moderate
    case heavy

    var color: Color {
        switch self {
        case .free: return Color(red: 0.2, green: 0.55, blue: 1.0)
        case .moderate: return Color(red: 1.0, green: 0.82, blue: 0.1)
        case .heavy: return Color(red: 1.0, green: 0.22, blue: 0.2)
        }
    }

    static func from(step: MKRoute.Step, route: MKRoute) -> TrafficLevel {
        guard route.distance > 0, route.expectedTravelTime > 0, step.distance > 0 else {
            return .free
        }
        let routeKmh = (route.distance / route.expectedTravelTime) * 3.6
        let stepShare = step.distance / route.distance
        let estimatedStepKmh = max(8, routeKmh * (0.75 + stepShare))

        if estimatedStepKmh < 22 { return .heavy }
        if estimatedStepKmh < 48 { return .moderate }
        return .free
    }
}

enum RoutePlanner {
    private static let forbiddenTokens = [
        "autostrada", "tangenziale", "motorway", "highway",
        "ra ", " ss ", " superstrada", " pedaggio", " toll ",
        " a1", " a4", " a7", " a8", " a9", " a10", " a11", " a12",
        " a13", " a14", " a15", " a16", " a21", " a22", " a23", " a24",
        " a25", " a26", " a27", " a28", " a29", " a30", " a31", " a32"
    ]

    static func configure125ccRequest(from source: MKMapItem, to destination: MKMapItem) -> MKDirections.Request {
        let request = MKDirections.Request()
        request.source = source
        request.destination = destination
        request.transportType = .automobile
        request.requestsAlternateRoutes = true
        request.highwayPreference = .avoid
        request.tollPreference = .avoid
        return request
    }

    static func best125ccRoute(from routes: [MKRoute]) -> MKRoute? {
        let legal = routes.filter { !usesForbiddenRoads($0) }
        return legal.min(by: { $0.expectedTravelTime < $1.expectedTravelTime }) ?? routes.first
    }

    static func usesForbiddenRoads(_ route: MKRoute) -> Bool {
        route.steps.contains(where: stepUsesForbiddenRoad)
    }

    static func stepUsesForbiddenRoad(_ step: MKRoute.Step) -> Bool {
        let text = step.instructions.lowercased()
        return forbiddenTokens.contains(where: { text.contains($0) })
    }

    static func trafficSegments(for route: MKRoute) -> [TrafficSegment] {
        route.steps.compactMap { step in
            guard step.distance > 20 else { return nil }
            let count = step.polyline.pointCount
            guard count > 0 else { return nil }
            var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: count)
            step.polyline.getCoordinates(&coords, range: NSRange(location: 0, length: count))
            return TrafficSegment(coordinates: coords, level: TrafficLevel.from(step: step, route: route))
        }
    }

    static func mergedPolyline(from route: MKRoute) -> MKPolyline {
        route.polyline
    }

    /// Estimates whether a route step is mostly urban, mixed, or extra-urban.
    static func drivingContext(for step: MKRoute.Step, route: MKRoute) -> RouteDrivingContext {
        guard route.distance > 0, route.expectedTravelTime > 0, step.distance > 0 else {
            return .urban
        }

        let routeKmh = (route.distance / route.expectedTravelTime) * 3.6
        let stepShare = step.distance / route.distance
        let estimatedStepKmh = max(8, routeKmh * (0.75 + stepShare))

        let text = step.instructions.lowercased()
        let urbanHints = ["centro", "piazza", "via ", "viale ", "corso ", "largo ", "strada ", "rotonda"]
        let looksUrban = urbanHints.contains(where: { text.contains($0) })

        if estimatedStepKmh < 45 || looksUrban { return .urban }
        if estimatedStepKmh < 72 { return .mixed }
        return .extraUrban
    }
}

enum RouteDrivingContext {
    case urban
    case mixed
    case extraUrban

    var consumptionMultiplier: Double {
        switch self {
        case .urban: return 1.18
        case .mixed: return 1.0
        case .extraUrban: return 0.92
        }
    }
}
