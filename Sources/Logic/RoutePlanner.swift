import Foundation
import MapKit
import SwiftUI

struct TrafficSegment: Identifiable {
    let id = UUID()
    let coordinates: [CLLocationCoordinate2D]
    let level: TrafficLevel
}

enum TrafficLevel: Equatable {
    case free
    case moderate
    case heavy

    var color: Color {
        switch self {
        case .free:
            return Color(red: 0.0, green: 0.478, blue: 1.0)
        case .moderate:
            return Color(red: 1.0, green: 0.584, blue: 0.0)
        case .heavy:
            return Color(red: 0.937, green: 0.204, blue: 0.173)
        }
    }

    var haloColor: Color { color.opacity(0.22) }
    var glowColor: Color { color.opacity(0.42) }

    static func from(step: MKRoute.Step, route: MKRoute) -> TrafficLevel {
        guard route.distance > 0, route.expectedTravelTime > 0, step.distance > 30 else {
            return .free
        }

        let freeFlowKmh = estimatedFreeFlowSpeed(for: step)
        let stepShare = step.distance / route.distance
        let stepSeconds = max(1, route.expectedTravelTime * stepShare)
        let actualKmh = (step.distance / stepSeconds) * 3.6
        let ratio = actualKmh / freeFlowKmh

        if ratio < 0.42 { return .heavy }
        if ratio < 0.68 { return .moderate }
        return .free
    }

    private static func estimatedFreeFlowSpeed(for step: MKRoute.Step) -> Double {
        let text = step.instructions.lowercased()

        if text.contains("autostrada") || text.contains("superstrada") { return 95 }
        if text.contains("tangenziale") || text.contains("raccordo") { return 75 }
        if text.contains("ss ") || text.contains("strada statale") { return 65 }
        if step.distance > 8000 { return 72 }
        if step.distance > 3500 { return 58 }
        if step.distance > 1200 { return 48 }
        return 32
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
        var segments: [TrafficSegment] = []

        for step in route.steps where step.distance > 20 {
            let count = step.polyline.pointCount
            guard count > 1 else { continue }

            var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: count)
            step.polyline.getCoordinates(&coords, range: NSRange(location: 0, length: count))

            let level = TrafficLevel.from(step: step, route: route)
            let refined = subdivide(coords, level: level)

            if let previous = segments.last?.level, previous != level, refined.count >= 2 {
                let blend = blendSegment(between: segments.last!.coordinates.last!, and: refined[0].coordinates.first!, from: previous, to: level)
                segments.append(blend)
            }

            segments.append(contentsOf: refined)
        }

        return segments
    }

    private static func subdivide(_ coordinates: [CLLocationCoordinate2D], level: TrafficLevel) -> [TrafficSegment] {
        guard coordinates.count > 2 else {
            return [TrafficSegment(coordinates: coordinates, level: level)]
        }

        let chunkSize = 12
        var result: [TrafficSegment] = []
        var index = 0

        while index < coordinates.count - 1 {
            let end = min(index + chunkSize, coordinates.count - 1)
            let slice = Array(coordinates[index...end])
            if slice.count >= 2 {
                result.append(TrafficSegment(coordinates: slice, level: level))
            }
            index = end
        }

        return result
    }

    private static func blendSegment(
        between start: CLLocationCoordinate2D,
        and end: CLLocationCoordinate2D,
        from: TrafficLevel,
        to: TrafficLevel
    ) -> TrafficSegment {
        let mid = CLLocationCoordinate2D(
            latitude: (start.latitude + end.latitude) / 2,
            longitude: (start.longitude + end.longitude) / 2
        )
        let blendLevel: TrafficLevel = (from == .heavy || to == .heavy) ? .moderate : .moderate
        return TrafficSegment(coordinates: [start, mid, end], level: blendLevel)
    }

    static func mergedPolyline(from route: MKRoute) -> MKPolyline {
        route.polyline
    }

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
