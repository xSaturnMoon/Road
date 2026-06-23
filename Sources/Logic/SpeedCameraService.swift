import Foundation
import CoreLocation
import MapKit

struct SpeedCamera: Identifiable, Equatable {
    enum CameraType: String {
        case fixed
        case mobile
        case section
        case redLight

        var label: String {
            switch self {
            case .fixed: return "Autovelox"
            case .mobile: return "Autovelox mobile"
            case .section: return "Tutor"
            case .redLight: return "T-red"
            }
        }
    }

    let id: String
    let coordinate: CLLocationCoordinate2D
    let maxSpeedKmh: Int?
    let type: CameraType
    let sources: Set<String>

    static func == (lhs: SpeedCamera, rhs: SpeedCamera) -> Bool {
        lhs.id == rhs.id
    }
}

struct SpeedCameraAlert: Equatable {
    let camera: SpeedCamera
    let distanceMeters: Int

    var isImminent: Bool { distanceMeters <= 250 }
}

/// Aggregates speed-camera data from OpenStreetMap (Overpass) using the standard
/// tags used by OsmAnd, Organic Maps, Waze imports, and official `enforcement=*` schema.
@MainActor
final class SpeedCameraService: ObservableObject {
    static let shared = SpeedCameraService()

    @Published private(set) var camerasOnRoute: [SpeedCamera] = []
    @Published private(set) var activeAlert: SpeedCameraAlert?
    @Published private(set) var isLoading = false

    private var allCameras: [SpeedCamera] = []
    private var alertedCameraIDs: Set<String> = []
    private var loadTask: Task<Void, Never>?

    private init() {}

    func loadCameras(along route: MKRoute) {
        loadTask?.cancel()
        loadTask = Task { await fetchCameras(along: route) }
    }

    func update(for location: CLLocation, heading: CLLocationDirection) {
        guard !allCameras.isEmpty else {
            activeAlert = nil
            return
        }

        let userPoint = location.coordinate
        let candidates = allCameras.compactMap { camera -> (SpeedCamera, CLLocationDistance, CLLocationDirection)? in
            let cameraLocation = CLLocation(latitude: camera.coordinate.latitude, longitude: camera.coordinate.longitude)
            let distance = location.distance(from: cameraLocation)
            guard distance <= 900 else { return nil }

            let bearing = bearingDegrees(from: userPoint, to: camera.coordinate)
            guard isAhead(bearing: bearing, heading: heading, tolerance: 55) else { return nil }

            return (camera, distance, bearing)
        }
        .sorted { $0.1 < $1.1 }

        if let nearest = candidates.first {
            activeAlert = SpeedCameraAlert(camera: nearest.0, distanceMeters: Int(nearest.1.rounded()))
        } else {
            activeAlert = nil
        }

        camerasOnRoute = allCameras.filter { camera in
            let distance = location.distance(from: CLLocation(latitude: camera.coordinate.latitude, longitude: camera.coordinate.longitude))
            return distance <= 1_500
        }
    }

    func reset() {
        loadTask?.cancel()
        allCameras = []
        camerasOnRoute = []
        activeAlert = nil
        alertedCameraIDs = []
        isLoading = false
    }

    private func fetchCameras(along route: MKRoute) async {
        isLoading = true
        defer { isLoading = false }

        let rect = route.polyline.boundingMapRect.insetBy(dx: -2_500, dy: -2_500)
        let southWest = MKMapPoint(x: rect.minX, y: rect.maxY).coordinate
        let northEast = MKMapPoint(x: rect.maxX, y: rect.minY).coordinate
        let south = min(southWest.latitude, northEast.latitude)
        let north = max(southWest.latitude, northEast.latitude)
        let west = min(southWest.longitude, northEast.longitude)
        let east = max(southWest.longitude, northEast.longitude)

        let query = """
        [out:json][timeout:25];
        (
          node["highway"="speed_camera"](\(south),\(west),\(north),\(east));
          node["enforcement"="maxspeed"](\(south),\(west),\(north),\(east));
          node["man_made"="surveillance"]["surveillance:type"="fixed_speed_camera"](\(south),\(west),\(north),\(east));
          node["man_made"="surveillance"]["surveillance"="traffic"](\(south),\(west),\(north),\(east));
          node["highway"="speed_camera"]["camera:type"="mobile"](\(south),\(west),\(north),\(east));
        );
        out body;
        """

        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }

        do {
            var request = URLRequest(url: URL(string: "https://overpass-api.de/api/interpreter")!)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = "data=\(encoded)".data(using: .utf8)

            let (data, response) = try await URLSession.shared.data(for: request)
            guard !Task.isCancelled else { return }
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return }

            let parsed = try JSONDecoder().decode(OverpassCameraResponse.self, from: data)
            let merged = mergeCameras(from: parsed.elements)
            allCameras = merged.filter { cameraIsNearRoute($0, route: route, toleranceMeters: 120) }
            camerasOnRoute = allCameras
        } catch {
            allCameras = []
            camerasOnRoute = []
        }
    }

    private func mergeCameras(from elements: [OverpassCameraElement]) -> [SpeedCamera] {
        var buckets: [String: (coord: CLLocationCoordinate2D, speed: Int?, types: [SpeedCamera.CameraType], sources: Set<String>)] = [:]

        for element in elements {
            guard let lat = element.lat, let lon = element.lon else { continue }
            let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            let key = String(format: "%.4f,%.4f", lat, lon)

            let type = cameraType(from: element.tags ?? [:])
            let speed = parseMaxSpeed(element.tags?["maxspeed"])
            let source = element.tags?["source"] ?? "OpenStreetMap"

            if var existing = buckets[key] {
                existing.types.append(type)
                if existing.speed == nil { existing.speed = speed }
                existing.sources.insert(source)
                buckets[key] = existing
            } else {
                buckets[key] = (coordinate, speed, [type], [source])
            }
        }

        return buckets.map { key, value in
            let resolvedType: SpeedCamera.CameraType = value.types.contains(.section) ? .section
                : value.types.contains(.mobile) ? .mobile
                : value.types.contains(.redLight) ? .redLight
                : .fixed
            return SpeedCamera(
                id: key,
                coordinate: value.coord,
                maxSpeedKmh: value.speed,
                type: resolvedType,
                sources: value.sources
            )
        }
    }

    private func cameraType(from tags: [String: String]) -> SpeedCamera.CameraType {
        let enforcement = tags["enforcement"]?.lowercased() ?? ""
        let highway = tags["highway"]?.lowercased() ?? ""
        let cameraType = tags["camera:type"]?.lowercased() ?? ""

        if enforcement.contains("average") || tags["enforcement:maxspeed"]?.contains("average") == true {
            return .section
        }
        if cameraType == "mobile" || tags["fixed"] == "no" {
            return .mobile
        }
        if tags["surveillance:type"]?.contains("red_light") == true {
            return .redLight
        }
        if highway == "speed_camera" || enforcement == "maxspeed" {
            return .fixed
        }
        return .fixed
    }

    private func parseMaxSpeed(_ raw: String?) -> Int? {
        guard let raw else { return nil }
        let digits = raw.prefix { $0.isNumber }
        guard let value = Int(digits), (20...160).contains(value) else { return nil }
        return value
    }

    private func cameraIsNearRoute(_ camera: SpeedCamera, route: MKRoute, toleranceMeters: Double) -> Bool {
        let point = MKMapPoint(camera.coordinate)
        let steps = route.steps
        for step in steps where step.distance > 0 {
            let count = step.polyline.pointCount
            guard count > 1 else { continue }
            var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: count)
            step.polyline.getCoordinates(&coords, range: NSRange(location: 0, length: count))
            for coord in coords {
                let mapPoint = MKMapPoint(coord)
                if mapPoint.distance(to: point) <= toleranceMeters {
                    return true
                }
            }
        }
        return false
    }

    private func bearingDegrees(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CLLocationDirection {
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let deltaLon = (to.longitude - from.longitude) * .pi / 180
        let y = sin(deltaLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
        let radians = atan2(y, x)
        return (radians * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    private func isAhead(bearing: CLLocationDirection, heading: CLLocationDirection, tolerance: Double) -> Bool {
        let delta = abs(((bearing - heading + 540).truncatingRemainder(dividingBy: 360)) - 180)
        return delta <= tolerance
    }
}

private struct OverpassCameraResponse: Decodable {
    let elements: [OverpassCameraElement]
}

private struct OverpassCameraElement: Decodable {
    let lat: Double?
    let lon: Double?
    let tags: [String: String]?
}