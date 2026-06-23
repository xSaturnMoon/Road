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
    private static let strongForbiddenPhrases = [
        "autostrada", "autostrade", "in autostrada", "sull'autostrada", "sull'autostrade",
        "tangenziale est", "tangenziale ovest", "tangenziale nord", "tangenziale sud",
        "tangenziale interna", "tangenziale esterna", " sulla tangenziale", " in tangenziale",
        "raccordo anulare", "grande raccordo anulare", "g.r.a.", " g.r.a ",
        "casello autostradale", " casello ", " pedaggio", " pedaggi ", "stazione di pedaggio",
        "superstrada a pedaggio", "immettersi in autostrada", "prendere l'autostrada",
        "entrare in autostrada", "diramazione autostradale", "bretella autostradale",
        "viadotto autostradale", " tratto autostradale"
    ]

    private static let highwayInstructionPatterns = [
        #"prendere\s+(?:l['']|la\s+)?a\s*\d{1,2}\b"#,
        #"immettersi\s+(?:su\s+)?(?:l['']|la\s+)?a\s*\d{1,2}\b"#,
        #"continuare\s+(?:su\s+)?(?:l['']|la\s+)?a\s*\d{1,2}\b"#,
        #"autostrada\s+a\s*\d{1,2}\b"#,
        #"tangenziale\s+(?:di\s+)?(?:roma|milano|torino|napoli|bologna|firenze|genova|palermo)"#
    ]

    struct RouteSelection {
        let route: MKRoute
        let isFullyLegal: Bool
        let forbiddenStepCount: Int
    }

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

    /// Prefers fully legal 125cc routes. Falls back to the least-restricted MapKit alternative
    /// (highways already avoided) so the user always gets a navigable preview.
    static func select125ccRoute(from routes: [MKRoute]) -> RouteSelection? {
        guard !routes.isEmpty else { return nil }

        let ranked = routes.map { route -> RouteSelection in
            let forbiddenCount = route.steps.filter(stepUsesForbiddenRoad).count
            return RouteSelection(route: route, isFullyLegal: forbiddenCount == 0, forbiddenStepCount: forbiddenCount)
        }
        .sorted { lhs, rhs in
            if lhs.forbiddenStepCount != rhs.forbiddenStepCount {
                return lhs.forbiddenStepCount < rhs.forbiddenStepCount
            }
            return lhs.route.expectedTravelTime < rhs.route.expectedTravelTime
        }

        return ranked.first
    }

    static func best125ccRoute(from routes: [MKRoute]) -> MKRoute? {
        select125ccRoute(from: routes)?.route
    }

    static func usesForbiddenRoads(_ route: MKRoute) -> Bool {
        route.steps.contains(where: stepUsesForbiddenRoad)
    }

    static func stepUsesForbiddenRoad(_ step: MKRoute.Step) -> Bool {
        let text = step.instructions.lowercased()

        if strongForbiddenPhrases.contains(where: { text.contains($0) }) {
            return true
        }

        for pattern in highwayInstructionPatterns {
            if text.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }

        return false
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
                let blend = blendSegment(
                    between: segments.last!.coordinates.last!,
                    and: refined[0].coordinates.first!,
                    from: previous,
                    to: level
                )
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
        return TrafficSegment(coordinates: [start, mid, end], level: .moderate)
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
