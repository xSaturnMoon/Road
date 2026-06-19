import SwiftUI
import MapKit
import CoreLocation

// MARK: - Map Style

enum MapStyleMode: String, CaseIterable, Identifiable {
    case theme = "Theme"
    case standard = "Standard"
    case satellite = "Satellite"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .theme: return "circle.lefthalf.filled"
        case .standard: return "map"
        case .satellite: return "globe.americas.fill"
        }
    }

    var subtitle: String {
        switch self {
        case .theme: return "Follows device appearance"
        case .standard: return "Classic road map"
        case .satellite: return "Aerial imagery"
        }
    }

    func style(showsTraffic: Bool) -> MapStyle {
        switch self {
        case .theme:
            return .standard(elevation: .flat, emphasis: .muted, showsTraffic: showsTraffic)
        case .standard:
            return .standard(elevation: .realistic, showsTraffic: showsTraffic)
        case .satellite:
            return .hybrid(elevation: .realistic, showsTraffic: showsTraffic)
        }
    }
}

private enum MapAnimation {
    static let spring = Animation.spring(response: 0.4, dampingFraction: 0.88)
    static let style = Animation.smooth(duration: 0.55)
    static let menu = Animation.smooth(duration: 0.32)
}

private let mapBarHeight: CGFloat = 44

// MARK: - Location Manager

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    @Published var userLocation: CLLocationCoordinate2D?
    @Published var authStatus: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestWhenInUseAuthorization()
    }

    func requestLocation() {
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        userLocation = locations.last?.coordinate
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authStatus = manager.authorizationStatus
        if manager.authorizationStatus == .authorizedWhenInUse ||
           manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }
}

// MARK: - Route Info Model

struct RouteInfo {
    let placeName: String
    let distanceKm: Double
    let travelMinutes: Int
    let fuelLiters: Double
    let avoidsHighways: Bool

    var distanceString: String {
        distanceKm < 1 ? "\(Int(distanceKm * 1000)) m" : String(format: "%.1f km", distanceKm)
    }
    var timeString: String {
        travelMinutes < 60 ? "\(travelMinutes) min" : "\(travelMinutes / 60)h \(travelMinutes % 60)min"
    }
    var fuelString: String { String(format: "%.1f L", fuelLiters) }
}

// MARK: - Search Result

struct PlaceResult: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let subtitle: String
    let coordinate: CLLocationCoordinate2D

    static func == (lhs: PlaceResult, rhs: PlaceResult) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Map View

struct MapView: View {
    @Environment(\.colorScheme) private var colorScheme

    @StateObject private var locationManager = LocationManager()
    @ObservedObject private var motorcycle = MotorcycleStore.shared
    @ObservedObject private var appManager = AppManager.shared

    @AppStorage("map_style_mode") private var mapStyleModeRaw = MapStyleMode.standard.rawValue

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var mapStylePhase: CGFloat = 1
    @State private var userControlsCamera = false
    @State private var didInitialCenter = false

    @State private var searchText = ""
    @State private var isSearchActive = false
    @State private var searchResults: [PlaceResult] = []
    @FocusState private var searchFieldFocused: Bool

    @State private var selectedPlace: PlaceResult? = nil
    @State private var routePolyline: MKPolyline? = nil
    @State private var trafficSegments: [TrafficSegment] = []
    @State private var routeInfo: RouteInfo? = nil
    @State private var routeWarning: String? = nil

    @State private var showMapStyleMenu = false
    @State private var searchTask: Task<Void, Never>? = nil
    @State private var menuAppeared = false

    private var mapStyleMode: MapStyleMode {
        MapStyleMode(rawValue: mapStyleModeRaw) ?? .standard
    }

    var body: some View {
        ZStack(alignment: .top) {
            mapLayer
            overlayContent
        }
        .onAppear {
            locationManager.requestLocation()
            centerOnUserIfNeeded(force: true)
        }
        .onChange(of: motorcycle.presetID) { _, _ in
            if let place = selectedPlace { calculateRoute(to: place) }
        }
        .onChange(of: motorcycle.displacementCC) { _, _ in
            guard motorcycle.isCustom, let place = selectedPlace else { return }
            calculateRoute(to: place)
        }
        .onChange(of: motorcycle.stroke) { _, _ in
            guard motorcycle.isCustom, let place = selectedPlace else { return }
            calculateRoute(to: place)
        }
        .onChange(of: routeInfo) { _, newValue in
            appManager.isRouteActive = newValue != nil
        }
        .onChange(of: colorScheme) { _, _ in
            guard mapStyleMode == .theme else { return }
            animateMapStyleChange()
        }
    }

    private var overlayContent: some View {
        Group {
            if showMapStyleMenu {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture { closeMapStyleMenu() }
            }

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                Spacer()
            }
            .safeAreaPadding(.top)

            if showMapStyleMenu {
                mapStyleMenu
                    .padding(.trailing, 16)
                    .padding(.top, 8 + mapBarHeight + 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .safeAreaPadding(.top)
                    .allowsHitTesting(true)
            }

            if isSearchActive && !searchResults.isEmpty {
                searchDropdown
                    .padding(.horizontal, 16)
                    .padding(.top, 8 + mapBarHeight + 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .safeAreaPadding(.top)
            }

            if let info = routeInfo {
                VStack {
                    Spacer()
                    routeCard(info)
                }
                .ignoresSafeArea(edges: .bottom)
            }
        }
    }

    // MARK: - Map Layer

    private var mapLayer: some View {
        Map(position: $cameraPosition) {
            UserAnnotation()

            if let place = selectedPlace {
                Marker(place.name, coordinate: place.coordinate)
                    .tint(.red)
            }

            ForEach(trafficSegments) { segment in
                MapPolyline(coordinates: segment.coordinates)
                    .stroke(segment.level.color.opacity(0.35), style: StrokeStyle(lineWidth: 16, lineCap: .round, lineJoin: .round))
                MapPolyline(coordinates: segment.coordinates)
                    .stroke(segment.level.color.opacity(0.65), style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))
                MapPolyline(coordinates: segment.coordinates)
                    .stroke(segment.level.color, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            }
        }
        .mapStyle(mapStyleMode.style(showsTraffic: true))
        .mapControls { }
        .onMapCameraChange(frequency: .onEnd) {
            userControlsCamera = true
        }
        .opacity(mapStylePhase)
        .animation(MapAnimation.style, value: mapStyleModeRaw)
        .animation(MapAnimation.style, value: colorScheme)
        .ignoresSafeArea()
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(alignment: .center, spacing: 8) {
            searchField

            if !isSearchActive {
                mapToolButton(icon: "location.fill", isActive: false) {
                    userControlsCamera = false
                    centerOnUserIfNeeded(force: true)
                }

                mapToolButton(
                    icon: "square.3.layers.3d",
                    isActive: showMapStyleMenu
                ) {
                    toggleMapStyleMenu()
                }
            } else {
                Button {
                    withAnimation(MapAnimation.spring) {
                        isSearchActive = false
                        searchText = ""
                        searchResults = []
                        searchFieldFocused = false
                    }
                } label: {
                    Text("Cancel")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.blue)
                        .frame(height: mapBarHeight)
                }
            }
        }
        .animation(MapAnimation.spring, value: isSearchActive)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)

            ZStack(alignment: .leading) {
                TextField("Search city or address...", text: $searchText)
                    .font(.system(size: 15))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($searchFieldFocused)
                    .onChange(of: searchText) { _, val in triggerSearch(val) }
                    .onSubmit { triggerSearch(searchText) }

                if !isSearchActive {
                    Text(selectedPlace?.name ?? "Search destination...")
                        .font(.system(size: 15))
                        .foregroundStyle(selectedPlace == nil ? .secondary : .primary)
                        .lineLimit(1)
                        .allowsHitTesting(false)
                }
            }

            Spacer(minLength: 0)

            if isSearchActive && !searchText.isEmpty {
                Button {
                    searchText = ""
                    searchResults = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: mapBarHeight)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: mapBarHeight / 2))
        .contentShape(RoundedRectangle(cornerRadius: mapBarHeight / 2))
        .onTapGesture { activateSearch() }
    }

    private func activateSearch() {
        withAnimation(MapAnimation.spring) {
            isSearchActive = true
        }
        searchFieldFocused = true
    }

    private func mapToolButton(icon: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isActive ? .blue : .primary)
                .frame(width: mapBarHeight, height: mapBarHeight)
                .contentShape(Circle())
        }
        .glassEffect(.regular.interactive(), in: Circle())
    }

    // MARK: - Map Style Menu

    private var mapStyleMenu: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Map Style")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 2)

            ForEach(MapStyleMode.allCases) { mode in
                Button {
                    selectMapStyle(mode)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(mapStyleMode == mode ? .blue : .primary)
                            .frame(width: 22)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(mode.rawValue)
                                .font(.system(size: 15, weight: .semibold))
                            Text(mode.subtitle)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 8)

                        if mapStyleMode == mode {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.blue)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 248)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(.white.opacity(colorScheme == .dark ? 0.1 : 0.2), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.16), radius: 18, y: 8)
        .opacity(menuAppeared ? 1 : 0)
        .offset(y: menuAppeared ? 0 : -10)
        .animation(MapAnimation.menu, value: menuAppeared)
    }

    // MARK: - Search Dropdown

    private var searchDropdown: some View {
        VStack(spacing: 0) {
            ForEach(searchResults) { result in
                Button { selectPlace(result) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.red)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.name)
                                .font(.system(size: 14, weight: .medium))
                            Text(result.subtitle)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if result.id != searchResults.last?.id {
                    Divider().padding(.leading, 52)
                }
            }
        }
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.15), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.15), radius: 20, y: 8)
    }

    // MARK: - Route Card

    private func routeCard(_ info: RouteInfo) -> some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2.5)
                .fill(.secondary.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 14)

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(info.placeName)
                        .font(.system(size: 17, weight: .semibold))
                        .lineLimit(1)
                    Text("Route for \(motorcycle.displayName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if info.avoidsHighways {
                        Label("125cc legal route", systemImage: "checkmark.shield.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                }
                Spacer()
                Button {
                    clearRoute()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)

            if let routeWarning {
                Text(routeWarning)
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }

            HStack(spacing: 0) {
                statCell(icon: "arrow.triangle.swap", value: info.distanceString, label: "Distance", color: .blue)
                Divider().frame(height: 44)
                statCell(icon: "clock", value: info.timeString, label: "Time", color: .orange)
                Divider().frame(height: 44)
                statCell(icon: "fuelpump", value: info.fuelString, label: "Fuel", color: .green)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)

            Button {
                // Future: launch turn-by-turn
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                        .font(.system(size: 18))
                    Text("Start Navigation")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.blue, in: RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .padding(.bottom, 8)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(.white.opacity(0.12), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.18), radius: 24, y: -4)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func statCell(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 15, weight: .semibold))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Map Style Logic

    private func toggleMapStyleMenu() {
        if showMapStyleMenu {
            closeMapStyleMenu()
        } else {
            showMapStyleMenu = true
            menuAppeared = false
            withAnimation(MapAnimation.menu) {
                menuAppeared = true
            }
        }
    }

    private func closeMapStyleMenu() {
        withAnimation(MapAnimation.menu) {
            menuAppeared = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            showMapStyleMenu = false
        }
    }

    private func selectMapStyle(_ mode: MapStyleMode) {
        guard mode.rawValue != mapStyleModeRaw else {
            closeMapStyleMenu()
            return
        }
        closeMapStyleMenu()
        mapStyleModeRaw = mode.rawValue
        animateMapStyleChange()
    }

    private func animateMapStyleChange() {
        withAnimation(.easeOut(duration: 0.16)) {
            mapStylePhase = 0.92
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            withAnimation(MapAnimation.style) {
                mapStylePhase = 1
            }
        }
    }

    private func centerOnUserIfNeeded(force: Bool = false) {
        guard force || !userControlsCamera else { return }
        guard let loc = locationManager.userLocation else { return }

        let span = didInitialCenter ? 2000.0 : 3000.0
        didInitialCenter = true

        withAnimation(MapAnimation.spring) {
            cameraPosition = .region(MKCoordinateRegion(
                center: loc,
                latitudinalMeters: span,
                longitudinalMeters: span
            ))
        }
    }

    private func clearRoute() {
        withAnimation(MapAnimation.spring) {
            selectedPlace = nil
            routeInfo = nil
            routePolyline = nil
            trafficSegments = []
            routeWarning = nil
            appManager.isRouteActive = false
        }
    }

    // MARK: - Search Logic

    private func triggerSearch(_ query: String) {
        searchTask?.cancel()
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            return
        }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await performSearch(query)
        }
    }

    @MainActor
    private func performSearch(_ query: String) async {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        if let loc = locationManager.userLocation {
            request.region = MKCoordinateRegion(
                center: loc,
                latitudinalMeters: 200_000,
                longitudinalMeters: 200_000
            )
        }

        let search = MKLocalSearch(request: request)
        if let response = try? await search.start() {
            searchResults = response.mapItems.prefix(5).map { item in
                let location = item.placemark.location ?? CLLocation(latitude: item.placemark.coordinate.latitude, longitude: item.placemark.coordinate.longitude)
                PlaceResult(
                    name: item.name ?? "Place",
                    subtitle: [item.placemark.locality, item.placemark.administrativeArea]
                        .compactMap { $0 }.joined(separator: ", "),
                    coordinate: location.coordinate
                )
            }
        }
    }

    private func selectPlace(_ place: PlaceResult) {
        withAnimation(MapAnimation.spring) {
            isSearchActive = false
            searchText = ""
            searchResults = []
            searchFieldFocused = false
            selectedPlace = place
        }

        userControlsCamera = false
        withAnimation(MapAnimation.spring) {
            cameraPosition = .region(MKCoordinateRegion(
                center: place.coordinate,
                latitudinalMeters: 6000,
                longitudinalMeters: 6000
            ))
        }

        calculateRoute(to: place)
    }

    private func calculateRoute(to place: PlaceResult) {
        let destination = MKMapItem(
            location: CLLocation(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude),
            address: nil
        )

        let source: MKMapItem
        if let loc = locationManager.userLocation {
            source = MKMapItem(
                location: CLLocation(latitude: loc.latitude, longitude: loc.longitude),
                address: nil
            )
        } else {
            source = MKMapItem.forCurrentLocation()
        }

        let request = RoutePlanner.configure125ccRequest(from: source, to: destination)

        MKDirections(request: request).calculate { response, _ in
            DispatchQueue.main.async {
                guard let routes = response?.routes, !routes.isEmpty else { return }

                let route = RoutePlanner.best125ccRoute(from: routes) ?? routes[0]
                let isFullyLegal = !RoutePlanner.usesForbiddenRoads(route)

                self.routePolyline = RoutePlanner.mergedPolyline(from: route)
                self.trafficSegments = RoutePlanner.trafficSegments(for: route)
                self.routeWarning = isFullyLegal
                    ? nil
                    : "No fully legal 125cc route found. Showing the closest alternative without highways."

                let distKm = route.distance / 1000
                let baseMins = Int(route.expectedTravelTime / 60)
                let mins = self.motorcycle.travelMinutes(baseAutomobileMinutes: baseMins)
                let fuel = self.motorcycle.fuelLiters(forDistanceKm: distKm)

                withAnimation(MapAnimation.spring) {
                    self.routeInfo = RouteInfo(
                        placeName: place.name,
                        distanceKm: distKm,
                        travelMinutes: mins,
                        fuelLiters: fuel,
                        avoidsHighways: isFullyLegal
                    )
                }

                if !self.userControlsCamera {
                    withAnimation(MapAnimation.spring) {
                        self.cameraPosition = .rect(route.polyline.boundingMapRect.insetBy(dx: -5000, dy: -5000))
                    }
                }
            }
        }
    }
}
