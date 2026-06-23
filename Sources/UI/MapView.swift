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
    static let navigation = Animation.smooth(duration: 0.95)
    static let heading = Animation.linear(duration: 0.18)
}

private let mapBarHeight: CGFloat = 44
private let routeOutlineStroke = StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round)
private let routeFillStroke   = StrokeStyle(lineWidth: 6,  lineCap: .round, lineJoin: .round)

// MARK: - Location Manager

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    @Published var userLocation: CLLocationCoordinate2D?
    @Published var currentLocation: CLLocation?
    @Published var authStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var displaySpeedKmh: Int = 0
    @Published private(set) var deviceHeading: CLLocationDirection = 0

    private var previousSample: (location: CLLocation, date: Date)?
    private var filteredSpeedMs: Double = 0

    /// Speeds below this threshold (m/s) are treated as stationary (~2.5 km/h).
    private let stationarySpeedMs: Double = 0.69

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.activityType = .automotiveNavigation
        manager.distanceFilter = 5
        manager.headingFilter = 1
        manager.requestWhenInUseAuthorization()
    }

    func requestLocation() {
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
    }

    func startNavigationTracking() {
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = 2
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
    }

    func stopNavigationTracking() {
        // Keep heading active — needed for the direction cone on the user dot.
        manager.distanceFilter = 5
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
        userLocation = location.coordinate
        updateDisplaySpeed(from: location)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard newHeading.headingAccuracy >= 0, newHeading.headingAccuracy <= 30 else { return }
        let heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        guard heading >= 0 else { return }
        deviceHeading = heading
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authStatus = manager.authorizationStatus
        if manager.authorizationStatus == .authorizedWhenInUse ||
           manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    private func updateDisplaySpeed(from location: CLLocation) {
        let accuracy = location.horizontalAccuracy
        guard accuracy >= 0, accuracy <= 35 else {
            applyStationarySpeed()
            return
        }

        var speedMs: Double = 0

        if location.speed >= 0 {
            speedMs = Double(location.speed)
        }

        if let previous = previousSample {
            let elapsed = location.timestamp.timeIntervalSince(previous.date)
            if elapsed >= 0.35, elapsed <= 4 {
                let distance = location.distance(from: previous.location)
                let derivedMs = distance / elapsed

                if location.speed < 0 {
                    speedMs = derivedMs
                } else if abs(derivedMs - speedMs) <= 4 {
                    speedMs = (speedMs * 0.45) + (derivedMs * 0.55)
                }
            }
        }

        previousSample = (location, location.timestamp)
        filteredSpeedMs = (filteredSpeedMs * 0.65) + (speedMs * 0.35)

        if filteredSpeedMs < stationarySpeedMs {
            applyStationarySpeed()
        } else {
            displaySpeedKmh = Int((filteredSpeedMs * 3.6).rounded())
        }
    }

    private func applyStationarySpeed() {
        filteredSpeedMs = 0
        displaySpeedKmh = 0
    }
}

// MARK: - Models

struct RouteInfo: Equatable {
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

    var fuelString: String {
        if fuelLiters < 0.1 {
            return String(format: "%.2f L", fuelLiters)
        }
        return String(format: "%.1f L", fuelLiters)
    }
}

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
    @ObservedObject private var speedLimitService = SpeedLimitService.shared
    @ObservedObject private var speedCameraService = SpeedCameraService.shared

    @AppStorage("map_style_mode") private var mapStyleModeRaw = MapStyleMode.standard.rawValue

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var mapStylePhase: CGFloat = 1
    @State private var userControlsCamera = false
    @State private var didInitialCenter = false
    @State private var activeRoute: MKRoute?
    @State private var isProgrammaticCameraMove = false
    @State private var navigationHeading: CLLocationDirection = 0
    @State private var isNavigation3D = true

    @State private var searchText = ""
    @State private var isSearchActive = false
    @State private var searchResults: [PlaceResult] = []
    @FocusState private var searchFieldFocused: Bool

    @State private var selectedPlace: PlaceResult?
    @State private var trafficSegments: [TrafficSegment] = []
    @State private var routeInfo: RouteInfo?
    @State private var routeWarning: String?

    @State private var showMapStyleMenu = false
    @State private var searchTask: Task<Void, Never>?
    @State private var menuAppeared = false
    @State private var showIllegalRouteAlert = false

    private var mapStyleMode: MapStyleMode {
        MapStyleMode(rawValue: mapStyleModeRaw) ?? .standard
    }

    var body: some View {
        let view = ZStack(alignment: .top) {
            mapLayer
            menuDismissLayer
            topChrome
            styleMenuOverlay
            searchResultsOverlay
            routeOverlay
            routeWarningOverlay
            speedCameraAlertOverlay
        }
        return view
            .onAppear {
                locationManager.requestLocation()
                centerOnUserIfNeeded(force: true)
            }
            .onChange(of: motorcycle.presetID) { _, _ in
                guard let place = selectedPlace else { return }
                calculateRoute(to: place)
            }
            .onChange(of: motorcycle.displacementCC) { _, _ in
                guard motorcycle.isCustom, let place = selectedPlace else { return }
                calculateRoute(to: place)
            }
            .onChange(of: motorcycle.stroke) { _, _ in
                guard motorcycle.isCustom, let place = selectedPlace else { return }
                calculateRoute(to: place)
            }
            .onChange(of: routeInfo) { _, _ in
                syncRouteActiveState()
            }
            .onChange(of: appManager.isNavigating) { _, _ in
                syncRouteActiveState()
            }
            .onChange(of: locationManager.currentLocation) { _, location in
                guard appManager.isNavigating, let location else { return }
                speedLimitService.update(for: location)
                speedCameraService.update(for: location, heading: navigationHeading)
                followUserDuringNavigation(at: location)
            }
            .onChange(of: locationManager.deviceHeading) { _, _ in
                guard appManager.isNavigating, let location = locationManager.currentLocation else { return }
                followUserDuringNavigation(at: location)
            }
            .onChange(of: colorScheme) { _, _ in
                guard mapStyleMode == .theme else { return }
                animateMapStyleChange()
            }
            .toolbar(appManager.isRouteActive ? .hidden : .visible, for: .tabBar)
            .toolbarVisibility(appManager.isRouteActive ? .hidden : .visible, for: .tabBar)
    }

    // MARK: - Layers

    @ViewBuilder
    private var menuDismissLayer: some View {
        if showMapStyleMenu {
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .onTapGesture { closeMapStyleMenu() }
        }
    }

    private var topChrome: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, 16)
                .padding(.top, 8)
            Spacer()
        }
        .safeAreaPadding(.top)
    }

    @ViewBuilder
    private var styleMenuOverlay: some View {
        if showMapStyleMenu {
            mapStyleMenu
                .padding(.trailing, 16)
                .padding(.top, 8 + mapBarHeight + 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .safeAreaPadding(.top)
        }
    }

    @ViewBuilder
    private var searchResultsOverlay: some View {
        if isSearchActive && !searchResults.isEmpty {
            searchDropdown
                .padding(.horizontal, 16)
                .padding(.top, 8 + mapBarHeight + 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .safeAreaPadding(.top)
        }
    }

    @ViewBuilder
    private var routeWarningOverlay: some View {
        if routeInfo == nil, let routeWarning, selectedPlace != nil {
            VStack {
                Spacer()
                routeErrorCard(routeWarning)
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }

    @ViewBuilder
    private var speedCameraAlertOverlay: some View {
        if appManager.isNavigating, let alert = speedCameraService.activeAlert {
            VStack {
                Spacer()
                speedCameraAlertBanner(alert)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(MapAnimation.spring, value: alert.distanceMeters)
        }
    }

    private func speedCameraAlertBanner(_ alert: SpeedCameraAlert) -> some View {
        HStack(spacing: 12) {
            Image(systemName: alert.isImminent ? "exclamationmark.triangle.fill" : "camera.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(alert.isImminent ? .red : .orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(alert.camera.type.label)
                    .font(.system(size: 15, weight: .bold))
                Text(alertSubtitle(for: alert))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text("\(alert.distanceMeters) m")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(alert.isImminent ? .red : .primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(alert.isImminent ? Color.red.opacity(0.45) : Color.orange.opacity(0.25), lineWidth: 1)
        )
    }

    private func alertSubtitle(for alert: SpeedCameraAlert) -> String {
        if let limit = alert.camera.maxSpeedKmh {
            return "Limite \(limit) km/h · OpenStreetMap"
        }
        return "Segnalazione verificata · OpenStreetMap"
    }

    private func routeErrorCard(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.orange)
            Text(message)
                .font(.system(size: 15, weight: .medium))
                .multilineTextAlignment(.center)
            Button("Chiudi") { clearRoute() }
                .font(.system(size: 15, weight: .semibold))
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 12)
        .padding(.bottom, 20)
    }

    @ViewBuilder
    private var routeOverlay: some View {
        if let info = routeInfo, !appManager.isNavigating {
            VStack {
                Spacer()
                routeCard(info)
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }

    private var mapLayer: some View {
        Map(position: $cameraPosition) {
            mapContent
        }
        .mapStyle(mapStyleMode.style(showsTraffic: true))
        .mapControls { }
        .onMapCameraChange(frequency: .onEnd) { _ in
            if !isProgrammaticCameraMove {
                userControlsCamera = true
            }
        }
        .opacity(mapStylePhase)
        .animation(MapAnimation.style, value: mapStyleModeRaw)
        .animation(MapAnimation.style, value: colorScheme)
        .ignoresSafeArea()
    }

    @MapContentBuilder
    private var mapContent: some MapContent {
        UserAnnotation()

        if let place = selectedPlace {
            Marker(place.name, coordinate: place.coordinate)
                .tint(.red)
        }

        if appManager.isNavigating {
            ForEach(speedCameraService.camerasOnRoute) { camera in
                Marker(camera.type.label, coordinate: camera.coordinate)
                    .tint(camera.type == .section ? .purple : .orange)
            }
        }

        ForEach(trafficSegments) { segment in
            MapPolyline(coordinates: segment.coordinates)
                .stroke(.white, style: routeOutlineStroke)
            MapPolyline(coordinates: segment.coordinates)
                .stroke(segment.level.color, style: routeFillStroke)
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                if appManager.isNavigating {
                    exitNavigationButton
                } else {
                    searchField

                    if isSearchActive {
                        Button {
                            withAnimation(MapAnimation.spring) {
                                isSearchActive = false
                                searchText = ""
                                searchResults = []
                                searchFieldFocused = false
                            }
                        } label: {
                            Text("Annulla")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.blue)
                                .frame(height: mapBarHeight)
                        }
                    }
                }

                if appManager.isNavigating || !isSearchActive {
                    mapToolButton(icon: "location.fill", isActive: false) {
                        userControlsCamera = false
                        if appManager.isNavigating, let location = locationManager.currentLocation {
                            followUserDuringNavigation(at: location, animated: true)
                        } else {
                            centerOnUserIfNeeded(force: true)
                        }
                    }

                    mapToolButton(icon: "square.3.layers.3d", isActive: showMapStyleMenu) {
                        toggleMapStyleMenu()
                    }
                }
            }
            .animation(MapAnimation.spring, value: isSearchActive)
            .animation(MapAnimation.spring, value: appManager.isNavigating)

            if appManager.isNavigating {
                HStack(alignment: .top, spacing: 0) {
                    VStack(spacing: 10) {
                        speedLimitSignButton
                        currentSpeedButton
                    }

                    Spacer(minLength: 0)

                    perspectiveToggleButton
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private var perspectiveToggleButton: some View {
        Button {
            withAnimation(.smooth(duration: 0.38)) {
                isNavigation3D.toggle()
            }
            userControlsCamera = false
            if let location = locationManager.currentLocation {
                followUserDuringNavigation(at: location, animated: true)
            }
        } label: {
            Text(isNavigation3D ? "3D" : "2D")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .frame(width: mapBarHeight, height: mapBarHeight)
                .glassEffect(.regular.interactive(), in: Circle())
        }
        .buttonStyle(.plain)
    }

    private var exitNavigationButton: some View {
        Button(action: stopNavigation) {
            HStack(spacing: 8) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                Text("Esci")
                    .font(.system(size: 15, weight: .semibold))
                Spacer(minLength: 0)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: mapBarHeight, maxHeight: mapBarHeight)
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: mapBarHeight / 2))
            .contentShape(RoundedRectangle(cornerRadius: mapBarHeight / 2))
        }
        .buttonStyle(.plain)
    }

    private var speedLimitSignButton: some View {
        ZStack {
            Circle()
                .stroke(Color.red, lineWidth: 3.5)
                .frame(width: 36, height: 36)
            Text(speedLimitDisplay)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
        .frame(width: mapBarHeight, height: mapBarHeight)
        .glassEffect(.regular.interactive(), in: Circle())
    }

    private var currentSpeedButton: some View {
        Text("\(locationManager.displaySpeedKmh)")
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.primary)
            .contentTransition(.numericText())
            .animation(.smooth(duration: 0.25), value: locationManager.displaySpeedKmh)
            .frame(width: mapBarHeight, height: mapBarHeight)
            .glassEffect(.regular.interactive(), in: Circle())
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)

            if isSearchActive {
                TextField("Cerca città o indirizzo...", text: $searchText)
                    .font(.system(size: 15))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($searchFieldFocused)
                    .onChange(of: searchText) { _, val in triggerSearch(val) }
                    .onSubmit { triggerSearch(searchText) }
            } else {
                Text(selectedPlace?.name ?? "Cerca destinazione...")
                    .font(.system(size: 15))
                    .foregroundStyle(selectedPlace == nil ? .secondary : .primary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
        .frame(maxWidth: .infinity)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: mapBarHeight / 2))
        .contentShape(RoundedRectangle(cornerRadius: mapBarHeight / 2))
        .onTapGesture {
            guard !isSearchActive else { return }
            withAnimation(MapAnimation.spring) { isSearchActive = true }
            searchFieldFocused = true
        }
        .onChange(of: isSearchActive) { _, active in
            if active { searchFieldFocused = true }
        }
    }

    private var speedLimitDisplay: String {
        if speedLimitService.isLoading, speedLimitService.speedLimitKmh == nil {
            return "…"
        }
        if let limit = speedLimitService.speedLimitKmh {
            return "\(limit)"
        }
        return "—"
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
                mapStyleRow(mode)
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

    private func mapStyleRow(_ mode: MapStyleMode) -> some View {
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
                            if !result.subtitle.isEmpty {
                                Text(result.subtitle)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
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
        VStack(spacing: 18) {
            Capsule()
                .fill(.secondary.opacity(0.35))
                .frame(width: 36, height: 5)
                .padding(.top, 4)

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(info.placeName)
                        .font(.system(size: 21, weight: .bold))
                        .lineLimit(2)
                    Text(motorcycle.displayName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                    if info.avoidsHighways {
                        Label("Percorso 125cc", systemImage: "checkmark.shield.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.green)
                            .padding(.top, 2)
                    }
                }

                Spacer(minLength: 8)

                Button(action: clearRoute) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .background(.quaternary.opacity(0.55), in: Circle())
                }
            }

            if let routeWarning {
                Text(routeWarning)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            }

            HStack(spacing: 10) {
                routeStatPill(icon: "arrow.left.and.right", value: info.distanceString, label: "Distanza", tint: .blue)
                routeStatPill(icon: "clock.fill", value: info.timeString, label: "Tempo", tint: .orange)
                routeStatPill(icon: "fuelpump.fill", value: info.fuelString, label: "Carburante", tint: .green)
            }

            let isIllegal = routeWarning != nil
            Button {
                if isIllegal {
                    showIllegalRouteAlert = true
                } else {
                    startNavigation()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: isIllegal ? "exclamationmark.triangle.fill" : "location.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text(isIllegal ? "Percorso non consigliato" : "Avvia")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    LinearGradient(
                        colors: isIllegal
                            ? [Color.orange, Color.orange.opacity(0.82)]
                            : [Color.blue, Color.blue.opacity(0.82)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 16)
                )
            }
            .buttonStyle(.plain)
            .alert("Percorso con tratti non consentiti", isPresented: $showIllegalRouteAlert) {
                Button("Annulla", role: .cancel) { }
                Button("Avvia comunque", role: .destructive) { startNavigation() }
            } message: {
                Text("Questo percorso potrebbe includere autostrade o tangenziali vietate ai 125cc. Con la patente A1 non puoi circolare su queste strade.\n\nVuoi avviare la navigazione lo stesso?")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 28)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 28))
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(.white.opacity(colorScheme == .dark ? 0.08 : 0.18), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.14), radius: 28, y: -6)
        .padding(.horizontal, 12)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .onAppear { syncRouteActiveState() }
    }

    private func routeStatPill(icon: String, value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Actions

    private func toggleMapStyleMenu() {
        if showMapStyleMenu {
            closeMapStyleMenu()
        } else {
            showMapStyleMenu = true
            menuAppeared = false
            withAnimation(MapAnimation.menu) { menuAppeared = true }
        }
    }

    private func closeMapStyleMenu() {
        withAnimation(MapAnimation.menu) { menuAppeared = false }
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
        withAnimation(.easeOut(duration: 0.16)) { mapStylePhase = 0.92 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            withAnimation(MapAnimation.style) { mapStylePhase = 1 }
        }
    }

    private func centerOnUserIfNeeded(force: Bool = false) {
        guard force || !userControlsCamera else { return }
        guard let loc = locationManager.userLocation else { return }

        let span = didInitialCenter ? 2000.0 : 3000.0
        didInitialCenter = true

        setCamera(
            .region(MKCoordinateRegion(
                center: loc,
                latitudinalMeters: span,
                longitudinalMeters: span
            )),
            animation: MapAnimation.spring
        )
    }

    private func setCamera(_ position: MapCameraPosition, animation: Animation = MapAnimation.spring, duration: TimeInterval = 0.45) {
        isProgrammaticCameraMove = true
        withAnimation(animation) { cameraPosition = position }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.08) {
            isProgrammaticCameraMove = false
        }
    }

    private func clearRoute() {
        withAnimation(MapAnimation.spring) {
            selectedPlace = nil
            routeInfo = nil
            activeRoute = nil
            trafficSegments = []
            routeWarning = nil
            appManager.isNavigating = false
            syncRouteActiveState()
            speedLimitService.reset()
            speedCameraService.reset()
        }
    }

    private func syncRouteActiveState() {
        appManager.isRouteActive = routeInfo != nil && !appManager.isNavigating
    }

    private func startNavigation() {
        guard routeInfo != nil else { return }
        closeMapStyleMenu()
        userControlsCamera = false
        isNavigation3D = true

        withAnimation(MapAnimation.spring) {
            appManager.isNavigating = true
            syncRouteActiveState()
        }

        locationManager.startNavigationTracking()

        if let route = activeRoute {
            speedCameraService.loadCameras(along: route)
        }

        if let location = locationManager.currentLocation {
            speedLimitService.update(for: location)
            followUserDuringNavigation(at: location, animated: true)
        }
    }

    private func stopNavigation() {
        locationManager.stopNavigationTracking()
        withAnimation(MapAnimation.spring) {
            appManager.isNavigating = false
            syncRouteActiveState()
        }
        speedLimitService.reset()
        speedCameraService.reset()
    }

    private func followUserDuringNavigation(at location: CLLocation, animated: Bool = false) {
        guard !userControlsCamera else { return }

        let heading = resolvedNavigationHeading(for: location)
        let pitch = isNavigation3D ? 62.0 : 0.0
        let distance = isNavigation3D ? 260.0 : 520.0
        let center = offsetCoordinate(
            from: location.coordinate,
            bearing: heading,
            distanceMeters: isNavigation3D ? 90 : 0
        )

        let camera = MapCamera(
            centerCoordinate: center,
            distance: distance,
            heading: heading,
            pitch: pitch
        )

        if animated {
            setCamera(.camera(camera), animation: MapAnimation.navigation, duration: 0.95)
        } else {
            isProgrammaticCameraMove = true
            cameraPosition = .camera(camera)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                isProgrammaticCameraMove = false
            }
        }
    }

    private func resolvedNavigationHeading(for location: CLLocation) -> CLLocationDirection {
        let moving = locationManager.displaySpeedKmh >= 4
        let target: CLLocationDirection

        if moving, location.course >= 0 {
            target = location.course
        } else if locationManager.deviceHeading >= 0 {
            target = locationManager.deviceHeading
        } else if navigationHeading > 0 {
            target = navigationHeading
        } else {
            target = 0
        }

        return smoothHeading(toward: target)
    }

    private func smoothHeading(toward target: CLLocationDirection) -> CLLocationDirection {
        let delta = ((target - navigationHeading + 540).truncatingRemainder(dividingBy: 360)) - 180
        navigationHeading = (navigationHeading + delta * 0.32 + 360).truncatingRemainder(dividingBy: 360)
        return navigationHeading
    }

    private func offsetCoordinate(
        from coordinate: CLLocationCoordinate2D,
        bearing: CLLocationDirection,
        distanceMeters: Double
    ) -> CLLocationCoordinate2D {
        guard distanceMeters > 0 else { return coordinate }

        let earthRadius = 6_378_137.0
        let bearingRad = bearing * .pi / 180
        let latRad = coordinate.latitude * .pi / 180
        let lonRad = coordinate.longitude * .pi / 180
        let angularDistance = distanceMeters / earthRadius

        let newLat = asin(
            sin(latRad) * cos(angularDistance) +
            cos(latRad) * sin(angularDistance) * cos(bearingRad)
        )
        let newLon = lonRad + atan2(
            sin(bearingRad) * sin(angularDistance) * cos(latRad),
            cos(angularDistance) - sin(latRad) * sin(newLat)
        )

        return CLLocationCoordinate2D(
            latitude: newLat * 180 / .pi,
            longitude: newLon * 180 / .pi
        )
    }

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

        guard let response = try? await MKLocalSearch(request: request).start() else { return }
        searchResults = response.mapItems.prefix(5).compactMap(placeResult(from:))
    }

    private func placeResult(from item: MKMapItem) -> PlaceResult? {
        let coordinate = item.location.coordinate
        return PlaceResult(
            name: item.name ?? "Place",
            subtitle: MapSearchFormatting.subtitle(for: item),
            coordinate: coordinate
        )
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
        setCamera(
            .region(MKCoordinateRegion(
                center: place.coordinate,
                latitudinalMeters: 6000,
                longitudinalMeters: 6000
            ))
        )

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
                guard let routes = response?.routes, !routes.isEmpty else {
                    routeInfo = nil
                    routeWarning = "Impossibile calcolare un percorso verso la destinazione."
                    return
                }

                guard let selection = RoutePlanner.select125ccRoute(from: routes) else {
                    routeInfo = nil
                    routeWarning = "Impossibile calcolare un percorso verso la destinazione."
                    return
                }

                let route = selection.route
                let isFullyLegal = selection.isFullyLegal

                activeRoute = route
                trafficSegments = RoutePlanner.trafficSegments(for: route)
                routeWarning = isFullyLegal
                    ? nil
                    : "Attenzione: il percorso potrebbe includere tratti non consentiti a 125cc. Verifica prima di partire."

                let distKm = route.distance / 1000
                let baseMins = Int(route.expectedTravelTime / 60)
                let mins = motorcycle.travelMinutes(baseAutomobileMinutes: baseMins)
                let fuel = motorcycle.fuelLiters(forRoute: route)

                withAnimation(MapAnimation.spring) {
                    routeInfo = RouteInfo(
                        placeName: place.name,
                        distanceKm: distKm,
                        travelMinutes: mins,
                        fuelLiters: fuel,
                        avoidsHighways: isFullyLegal
                    )
                }
                syncRouteActiveState()

                if !userControlsCamera {
                    setCamera(
                        .rect(route.polyline.boundingMapRect.insetBy(dx: -5000, dy: -5000)),
                        duration: 0.55
                    )
                }
            }
        }
    }
}

// MARK: - Search formatting

private enum MapSearchFormatting {
    static func subtitle(for item: MKMapItem) -> String {
        let p = item.placemark
        var parts: [String] = []
        if let locality = p.locality { parts.append(locality) }
        if let adminArea = p.administrativeArea { parts.append(adminArea) }
        if let country = p.country { parts.append(country) }
        if !parts.isEmpty { return parts.joined(separator: ", ") }
        if let thoroughfare = p.thoroughfare { return thoroughfare }
        return ""
    }
}