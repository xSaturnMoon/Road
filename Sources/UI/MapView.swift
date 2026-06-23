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
}

private let mapBarHeight: CGFloat = 44
private let routeHaloStroke = StrokeStyle(lineWidth: 16, lineCap: .round, lineJoin: .round)
private let routeGlowStroke = StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round)
private let routeCoreStroke = StrokeStyle(lineWidth: 4.5, lineCap: .round, lineJoin: .round)

// MARK: - Location Manager

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    @Published var userLocation: CLLocationCoordinate2D?
    @Published var currentLocation: CLLocation?
    @Published var authStatus: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.activityType = .automotiveNavigation
        manager.distanceFilter = 5
        manager.requestWhenInUseAuthorization()
    }

    func requestLocation() {
        manager.startUpdatingLocation()
    }

    func startNavigationTracking() {
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = 3
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
        userLocation = location.coordinate
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authStatus = manager.authorizationStatus
        if manager.authorizationStatus == .authorizedWhenInUse ||
           manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
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

    @AppStorage("map_style_mode") private var mapStyleModeRaw = MapStyleMode.standard.rawValue

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var mapStylePhase: CGFloat = 1
    @State private var userControlsCamera = false
    @State private var didInitialCenter = false
    @State private var activeRoute: MKRoute?
    @State private var isProgrammaticCameraMove = false
    @State private var navigationHeading: CLLocationDirection = 0

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
            .onChange(of: routeInfo) { _, newValue in
                syncRouteActiveState(routeVisible: newValue != nil)
            }
            .onChange(of: appManager.isNavigating) { _, _ in
                syncRouteActiveState(routeVisible: routeInfo != nil)
            }
            .onChange(of: locationManager.currentLocation) { _, location in
                guard appManager.isNavigating, let location else { return }
                speedLimitService.update(for: location)
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

        ForEach(trafficSegments) { segment in
            let color = segment.level.color
            MapPolyline(coordinates: segment.coordinates)
                .stroke(segment.level.haloColor, style: routeHaloStroke)
            MapPolyline(coordinates: segment.coordinates)
                .stroke(segment.level.glowColor, style: routeGlowStroke)
            MapPolyline(coordinates: segment.coordinates)
                .stroke(color, style: routeCoreStroke)
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
                HStack(spacing: 10) {
                    speedLimitSignButton
                    currentSpeedButton
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
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
            .frame(height: mapBarHeight)
            .frame(maxWidth: .infinity)
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: mapBarHeight / 2))
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
        Text(currentSpeedDisplay)
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.primary)
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

    private var currentSpeedDisplay: String {
        guard let location = locationManager.currentLocation,
              location.speed >= 0,
              location.horizontalAccuracy >= 0,
              location.horizontalAccuracy <= 25 else {
            return "0"
        }
        return "\(Int((location.speed * 3.6).rounded()))"
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

            Button(action: startNavigation) {
                HStack(spacing: 10) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Avvia")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    LinearGradient(
                        colors: [Color.blue, Color.blue.opacity(0.82)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 16)
                )
            }
            .buttonStyle(.plain)
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
        .onAppear { syncRouteActiveState(routeVisible: true) }
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
            syncRouteActiveState(routeVisible: false)
            speedLimitService.reset()
        }
    }

    private func syncRouteActiveState(routeVisible: Bool) {
        appManager.isRouteActive = routeVisible || appManager.isNavigating
    }

    private func startNavigation() {
        guard routeInfo != nil else { return }
        closeMapStyleMenu()
        userControlsCamera = false

        withAnimation(MapAnimation.spring) {
            appManager.isNavigating = true
            syncRouteActiveState(routeVisible: true)
        }

        locationManager.startNavigationTracking()

        if let location = locationManager.currentLocation {
            speedLimitService.update(for: location)
            followUserDuringNavigation(at: location, animated: true)
        }
    }

    private func stopNavigation() {
        withAnimation(MapAnimation.spring) {
            appManager.isNavigating = false
            syncRouteActiveState(routeVisible: routeInfo != nil)
        }
        speedLimitService.reset()
    }

    private func followUserDuringNavigation(at location: CLLocation, animated: Bool = false) {
        guard !userControlsCamera else { return }

        if location.course >= 0 {
            navigationHeading = location.course
        }

        let camera = MapCamera(
            centerCoordinate: location.coordinate,
            distance: 260,
            heading: navigationHeading,
            pitch: 62
        )

        if animated {
            setCamera(.camera(camera), animation: MapAnimation.navigation, duration: 0.95)
        } else {
            isProgrammaticCameraMove = true
            cameraPosition = .camera(camera)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isProgrammaticCameraMove = false
            }
        }
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
                guard let routes = response?.routes, !routes.isEmpty else { return }

                let route = RoutePlanner.best125ccRoute(from: routes) ?? routes[0]
                let isFullyLegal = !RoutePlanner.usesForbiddenRoads(route)

                activeRoute = route
                trafficSegments = RoutePlanner.trafficSegments(for: route)
                routeWarning = isFullyLegal
                    ? nil
                    : "Nessun percorso 125cc completamente legale. Mostrata l'alternativa più vicina."

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
                syncRouteActiveState(routeVisible: true)

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