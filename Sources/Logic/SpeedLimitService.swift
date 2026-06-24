import Foundation
import CoreLocation

/// Resolves road speed limits using OpenStreetMap (Overpass API) with Italian
/// Codice della Strada defaults when OSM lacks an explicit `maxspeed` tag.
@MainActor
final class SpeedLimitService: ObservableObject {
    static let shared = SpeedLimitService()

    @Published private(set) var speedLimitKmh: Int?
    @Published private(set) var isLoading = false

    private var lastCoordinate: CLLocationCoordinate2D?
    private var lastFetchAt: Date?
    private var fetchTask: Task<Void, Never>?
    private var cache: [String: Int] = [:]

    private let minFetchInterval: TimeInterval = 4
    private let minMoveMeters: CLLocationDistance = 35

    private init() {}

    func update(for location: CLLocation) {
        guard location.horizontalAccuracy >= 0, location.horizontalAccuracy <= 40 else { return }

        if let last = lastCoordinate, let lastTime = lastFetchAt {
            let moved = CLLocation(latitude: last.latitude, longitude: last.longitude)
                .distance(from: location)
            if moved < minMoveMeters || Date().timeIntervalSince(lastTime) < minFetchInterval {
                return
            }
        }

        lastCoordinate = location.coordinate
        lastFetchAt = Date()

        let key = cacheKey(for: location.coordinate)
        if let cached = cache[key] {
            speedLimitKmh = cached
            return
        }

        fetchTask?.cancel()
        fetchTask = Task { await fetchSpeedLimit(at: location.coordinate, cacheKey: key) }
    }

    func reset() {
        fetchTask?.cancel()
        speedLimitKmh = nil
        isLoading = false
        lastCoordinate = nil
        lastFetchAt = nil
    }

    private func cacheKey(for coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%.3f,%.3f", coordinate.latitude, coordinate.longitude)
    }

    private func fetchSpeedLimit(at coordinate: CLLocationCoordinate2D, cacheKey key: String) async {
        isLoading = true
        defer { isLoading = false }

        let lat = coordinate.latitude
        let lon = coordinate.longitude

        let query = """
        [out:json][timeout:10];
        (
          way(around:60,\(lat),\(lon))["highway"]["maxspeed"];
          way(around:60,\(lat),\(lon))["highway"];
        );
        out tags;
        """

        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return
        }

        do {
            var request = URLRequest(url: URL(string: "https://overpass-api.de/api/interpreter")!)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = "data=\(encoded)".data(using: .utf8)

            let (data, response) = try await URLSession.shared.data(for: request)
            guard !Task.isCancelled else { return }
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return }

            let parsed = try JSONDecoder().decode(OverpassResponse.self, from: data)
            let limit = resolveLimit(from: parsed.elements)
            if let limit {
                cache[key] = limit
                speedLimitKmh = limit
            }
        } catch {
            // Keep previous value on network failure.
        }
    }

    private func resolveLimit(from elements: [OverpassElement]) -> Int? {
        let withMaxspeed = elements.compactMap { element -> (Int, String?)? in
            guard let tags = element.tags, let highway = tags.highway else { return nil }
            if let raw = tags.maxspeed, let value = parseMaxspeed(raw) {
                return (value, highway)
            }
            return nil
        }

        if let best = withMaxspeed.max(by: { roadPriority($0.1) < roadPriority($1.1) }) {
            return best.0
        }

        let highways = elements.compactMap { $0.tags?.highway }
        guard let highway = highways.max(by: { roadPriority($0) < roadPriority($1) }) else {
            return 50
        }
        return italianDefaultLimit(for: highway)
    }

    private func parseMaxspeed(_ raw: String) -> Int? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if trimmed.hasPrefix("it:") {
            switch trimmed {
            case "it:urban": return 50
            case "it:rural": return 90
            case "it:motorway": return 130
            default: break
            }
        }

        let digits = trimmed.prefix { $0.isNumber }
        if let value = Int(digits), (10...150).contains(value) {
            return value
        }
        return nil
    }

    private func italianDefaultLimit(for highway: String) -> Int {
        switch highway {
        case "motorway", "motorway_link": return 130
        case "trunk", "trunk_link": return 110
        case "primary", "primary_link": return 90
        case "secondary", "secondary_link": return 90
        case "tertiary", "tertiary_link": return 70
        case "living_street": return 30
        case "service": return 30
        case "residential", "unclassified", "road": return 50
        default: return 50
        }
    }

    private func roadPriority(_ highway: String?) -> Int {
        switch highway {
        case "motorway", "motorway_link": return 9
        case "trunk", "trunk_link": return 8
        case "primary", "primary_link": return 7
        case "secondary", "secondary_link": return 6
        case "tertiary", "tertiary_link": return 5
        case "unclassified", "residential": return 4
        case "living_street", "service": return 3
        default: return 1
        }
    }
}

private struct OverpassResponse: Decodable {
    let elements: [OverpassElement]
}

private struct OverpassElement: Decodable {
    let tags: OverpassTags?
}

private struct OverpassTags: Decodable {
    let highway: String?
    let maxspeed: String?
}
