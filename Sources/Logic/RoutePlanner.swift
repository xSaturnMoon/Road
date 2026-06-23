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
    private static let forbiddenSubstrings = [
        "autostrada", "autostrade", "tangenziale", "tangenz ", "motorway", "highway",
        "superstrada", " pedaggio", " pedaggi", " toll ", " casello ", " caselli ",
        "raccordo anulare", "raccordo autostradale", "raccordo ", "gra ", "g.r.a",
        "grande raccordo", " variante autostradale", " dir. autostrada",
        " uscita autostrada", " entrata autostrada", " bretella autostradale",
        " ssray", " diramazione autostradale", " aut ", " mi aut", " sv "
    ]

    private static let forbiddenHighwayPattern = try! NSRegularExpression(
        pattern: #"(?<![a-z0-9])(?:a\s?(?:1|4|5|6|7|8|9|10|11|12|13|14|15|16|18|19|20|21|22|23|24|25|26|27|28|29|30|31|32|33|35|50|51|52|55|56|57|91)|e\s?(?:35|45|55|70|80|90|612|45))(?![a-z0-9])"#,
        options: [.caseInsensitive]
    )

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

    /// Returns only a route that avoids autostrada and tangenziale. Never falls back to illegal roads.
    static func best125ccRoute(from routes: [MKRoute]) -> MKRoute? {
        routes
            .filter { !usesForbiddenRoads($0) }
            .min(by: { $0.expectedTravelTime < $1.expectedTravelTime })
    }

    static func usesForbiddenRoads(_ route: MKRoute) -> Bool {
        route.steps.contains(where: stepUsesForbiddenRoad)
    }

    static func stepUsesForbiddenRoad(_ step: MKRoute.Step) -> Bool {
        let text = step.instructions.lowercased()

        if forbiddenSubstrings.contains(where: { text.contains($0) }) {
            return true
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        if forbiddenHighwayPattern.firstMatch(in: text, options: [], range: range) != nil {
            return true
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
