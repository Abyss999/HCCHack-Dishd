import SwiftUI
import MapKit
import CoreLocation

// MARK: - TappableMapView

private struct TappableMapView: UIViewRepresentable {
    var pinnedCoordinate: CLLocationCoordinate2D?
    var centerOn: CLLocationCoordinate2D?
    var onTap: (CLLocationCoordinate2D) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onTap: onTap) }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.setRegion(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 29.6857, longitude: -95.4490),
            span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
        ), animated: false)
        let tap = UITapGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handleTap(_:)))
        map.addGestureRecognizer(tap)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        let existing = map.annotations.filter { !($0 is MKUserLocation) }

        if let coord = pinnedCoordinate {
            if let pin = existing.first as? MKPointAnnotation {
                pin.coordinate = coord
            } else {
                map.removeAnnotations(existing)
                let pin = MKPointAnnotation()
                pin.coordinate = coord
                map.addAnnotation(pin)
            }
        } else {
            map.removeAnnotations(existing)
        }

        if let center = centerOn, center.latitude != context.coordinator.lastCenteredLat {
            context.coordinator.lastCenteredLat = center.latitude
            map.setRegion(MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
            ), animated: true)
        }
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var onTap: (CLLocationCoordinate2D) -> Void
        var lastCenteredLat: Double = 0

        init(onTap: @escaping (CLLocationCoordinate2D) -> Void) { self.onTap = onTap }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let map = gesture.view as? MKMapView else { return }
            let coord = map.convert(gesture.location(in: map), toCoordinateFrom: map)
            onTap(coord)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }
            let view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "pin")
            view.markerTintColor = UIColor(red: 0.851, green: 0.467, blue: 0.341, alpha: 1)
            view.animatesWhenAdded = true
            return view
        }
    }
}

// MARK: - LocationManager

@MainActor
final class LocationManager: NSObject, ObservableObject {
    @Published var isLoading = false
    @Published var error: String?

    private let manager = CLLocationManager()
    var onResolved: ((CLLocationCoordinate2D) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestLocation() {
        error = nil
        isLoading = true
        let status = manager.authorizationStatus
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else if status == .denied || status == .restricted {
            isLoading = false
            error = "Location access denied. Enable it in Settings."
        } else {
            manager.requestLocation()
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.first else { return }
        Task { @MainActor in
            self.isLoading = false
            self.onResolved?(loc.coordinate)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.isLoading = false
            self.error = "Couldn't get location."
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let s = manager.authorizationStatus
            if s == .authorizedWhenInUse || s == .authorizedAlways {
                manager.requestLocation()
            } else if s == .denied || s == .restricted {
                self.isLoading = false
                self.error = "Location access denied."
            }
        }
    }
}

// MARK: - CreateSessionSheet

struct CreateSessionSheet: View {
    @EnvironmentObject var themeStore: ThemeStore
    @EnvironmentObject var authStore: AuthStore
    @Environment(\.colorScheme) var systemScheme
    @Environment(\.dismiss) private var dismiss
    var theme: AppTheme { AppTheme.current(for: themeStore.resolved(system: systemScheme)) }

    let homeVM: HomeViewModel
    var soloMode: Bool = false

    @StateObject private var locationMgr = LocationManager()
    @State private var pinnedCoordinate: CLLocationCoordinate2D? = CLLocationCoordinate2D(latitude: 29.6857, longitude: -95.4490)
    @State private var centerOn: CLLocationCoordinate2D?
    @State private var locationLabel = "5601 W Loop S, Houston, TX"
    @State private var isGeocoding = false

    @State private var searchText = ""
    @State private var isSearching = false
    @FocusState private var searchFocused: Bool

    // Per-session preference overrides (pre-filled from profile)
    @State private var sessionCuisines: [String] = []
    @State private var sessionRadius: Double = 16.0  // 10 mi default
    @State private var sessionBudgets: [String] = []
    @State private var sessionSwipeCeiling: Double = 10  // matches backend SWIPE_CEILING default

    private let cuisineOptions = [
        "Italian", "Mexican", "American", "Chinese", "Japanese", "Thai",
        "Korean", "Vietnamese", "Indian", "Mediterranean", "Greek",
        "French", "Spanish", "Middle Eastern", "BBQ", "Burgers",
        "Pizza", "Sushi", "Seafood", "Steakhouse", "Brunch", "Bakery",
        "Cafe", "Dessert", "Vegan", "Vegetarian"
    ]
    private let radiusMinKm: Double = 1.6   // ~1 mi
    private let radiusMaxKm: Double = 80.0  // ~50 mi
    private let budgetOptions = ["$", "$$", "$$$", "$$$$"]

    private var radiusMiles: Double { sessionRadius / 1.609 }

    private let geocoder = CLGeocoder()

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                // Handle bar
                HStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 3)
                        .fill(theme.textSecondary.opacity(0.3))
                        .frame(width: 36, height: 4)
                    Spacer()
                }
                .padding(.top, 12)
                .padding(.bottom, 14)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Header
                        VStack(alignment: .leading, spacing: 4) {
                            Text(soloMode ? "Solo Session" : "New Session")
                                .font(.system(size: 22, weight: .black))
                                .foregroundColor(theme.text)
                            Text("Search or tap the map to set your area.")
                                .font(.system(size: 14))
                                .foregroundColor(theme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Search bar
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(theme.textSecondary)
                                .font(.system(size: 14))

                            TextField("Search for a city or neighborhood…", text: $searchText)
                                .font(.system(size: 15))
                                .foregroundColor(theme.text)
                                .focused($searchFocused)
                                .submitLabel(.search)
                                .onSubmit { Task { await runSearch() } }

                            if isSearching {
                                ProgressView().tint(theme.primary).scaleEffect(0.75)
                            } else if !searchText.isEmpty {
                                Button { searchText = "" } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(theme.textSecondary)
                                        .font(.system(size: 14))
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(theme.inputBg)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.inputBorder))
                        .cornerRadius(10)

                        // Map — fixed height so it never gets squished
                        VStack(spacing: 0) {
                            TappableMapView(
                                pinnedCoordinate: pinnedCoordinate,
                                centerOn: centerOn,
                                onTap: { coord in
                                    searchFocused = false
                                    pinnedCoordinate = coord
                                    reverseGeocode(coord)
                                }
                            )
                            .frame(height: 240)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                            // Location strip
                            HStack(spacing: 8) {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(theme.primary)
                                    .font(.system(size: 15))

                                if isGeocoding {
                                    ProgressView().tint(theme.primary).scaleEffect(0.75)
                                    Text("Finding location…")
                                        .font(.system(size: 13))
                                        .foregroundColor(theme.textSecondary)
                                } else if !locationLabel.isEmpty {
                                    Text(locationLabel)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(theme.text)
                                        .lineLimit(1)
                                } else {
                                    Text("Search or tap anywhere on the map")
                                        .font(.system(size: 13))
                                        .foregroundColor(theme.textSecondary)
                                }

                                Spacer()

                                Button {
                                    locationMgr.onResolved = { coord in
                                        pinnedCoordinate = coord
                                        centerOn = coord
                                        reverseGeocode(coord)
                                    }
                                    locationMgr.requestLocation()
                                } label: {
                                    HStack(spacing: 4) {
                                        if locationMgr.isLoading {
                                            ProgressView().tint(theme.primary).scaleEffect(0.65)
                                        } else {
                                            Image(systemName: "location.fill")
                                                .font(.system(size: 11))
                                        }
                                        Text("My Location")
                                            .font(.system(size: 12, weight: .medium))
                                    }
                                    .foregroundColor(theme.primary)
                                }
                                .disabled(locationMgr.isLoading)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(theme.surface)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.cardBorder))
                            .padding(.top, 8)
                        }

                        if let err = locationMgr.error {
                            Text(err).font(.system(size: 12)).foregroundColor(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // Session settings card
                        settingsSection

                        PrimaryButton(
                            title: soloMode ? "Start Solo Session" : "Create Session",
                            isLoading: homeVM.isLoading,
                            isDisabled: pinnedCoordinate == nil && locationLabel.isEmpty
                        ) {
                            Task {
                                let lat = pinnedCoordinate?.latitude ?? 0
                                let lng = pinnedCoordinate?.longitude ?? 0
                                await homeVM.createSession(
                                    lat: lat, lng: lng,
                                    label: locationLabel.isEmpty ? nil : locationLabel,
                                    soloMode: soloMode,
                                    cuisineOverrides: sessionCuisines.isEmpty ? nil : sessionCuisines,
                                    radiusKmOverride: sessionRadius,
                                    budgetOverrides: sessionBudgets.isEmpty ? nil : sessionBudgets,
                                    swipeCeilingOverride: Int(sessionSwipeCeiling)
                                )
                                dismiss()
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .onAppear {
            // Prefill every session setting from the saved profile so the host
            // doesn't have to re-pick their defaults every time.
            if let prefs = authStore.user?.preferences {
                sessionCuisines = prefs.cuisinePreferences
                if prefs.maxDistanceKm > 0 {
                    // Clamp into the slider's range so the thumb is always visible.
                    sessionRadius = min(max(prefs.maxDistanceKm, radiusMinKm), radiusMaxKm)
                }
                if let b = prefs.budgetRange { sessionBudgets = [b] }
            }
        }
    }

    @ViewBuilder private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("SESSION FILTERS")

            // Radius slider
            settingRow(label: "Max range") {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Range")
                            .font(.system(size: 13))
                            .foregroundColor(theme.textSecondary)
                        Spacer()
                        Text("\(radiusMiles, specifier: "%.0f") mi")
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundColor(theme.primary)
                    }
                    Slider(value: $sessionRadius, in: radiusMinKm...radiusMaxKm, step: 0.8)
                        .tint(theme.primary)
                }
            }

            settingsDivider

            // Swipe limit
            settingRow(label: "Swipe limit per person") {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Limit")
                            .font(.system(size: 13))
                            .foregroundColor(theme.textSecondary)
                        Spacer()
                        Text("\(Int(sessionSwipeCeiling))")
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundColor(theme.primary)
                    }
                    Slider(value: $sessionSwipeCeiling, in: 3...30, step: 1)
                        .tint(theme.primary)
                }
            }

            settingsDivider

            // Budget (multi-select)
            settingRow(label: "Budget") {
                HStack(spacing: 8) {
                    ForEach(budgetOptions, id: \.self) { b in
                        let sel = sessionBudgets.contains(b)
                        Button {
                            if sel { sessionBudgets.removeAll { $0 == b } }
                            else { sessionBudgets.append(b) }
                        } label: {
                            Text(b)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(sel ? theme.primary : theme.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(sel ? theme.chipBg : theme.bg)
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(sel ? theme.chipBorder : theme.cardBorder, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            settingsDivider

            // Cuisine chips
            settingRow(label: "Cuisines") {
                let columns = [GridItem(.adaptive(minimum: 100), spacing: 8)]
                LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                    ForEach(cuisineOptions, id: \.self) { c in
                        let sel = sessionCuisines.contains(c)
                        Button {
                            if sel { sessionCuisines.removeAll { $0 == c } }
                            else { sessionCuisines.append(c) }
                        } label: {
                            Text(c)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(sel ? theme.primary : theme.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(sel ? theme.chipBg : theme.bg)
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(sel ? theme.chipBorder : theme.cardBorder, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(theme.cardBorder, lineWidth: 1))
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .tracking(0.6)
            .foregroundColor(theme.textSecondary.opacity(0.7))
    }

    @ViewBuilder
    private func settingRow<Content: View>(label: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(theme.text)
            content()
        }
    }

    private var settingsDivider: some View {
        Rectangle()
            .fill(theme.textSecondary.opacity(0.12))
            .frame(height: 1)
    }

    private func runSearch() async {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        searchFocused = false
        isSearching = true
        defer { isSearching = false }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.address, .pointOfInterest]

        guard let response = try? await MKLocalSearch(request: request).start(),
              let item = response.mapItems.first else { return }

        let coord = item.placemark.coordinate
        let p = item.placemark
        let city = p.locality ?? p.administrativeArea ?? ""
        let state = p.administrativeArea ?? ""
        let label = p.locality != nil ? "\(city), \(state)" : (state.isEmpty ? query : state)

        pinnedCoordinate = coord
        centerOn = coord
        locationLabel = label
    }

    private func reverseGeocode(_ coord: CLLocationCoordinate2D) {
        isGeocoding = true
        locationLabel = ""
        let loc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        geocoder.reverseGeocodeLocation(loc) { placemarks, _ in
            Task { @MainActor in
                self.isGeocoding = false
                if let p = placemarks?.first {
                    let city = p.locality ?? p.administrativeArea ?? ""
                    let state = p.administrativeArea ?? ""
                    self.locationLabel = p.locality != nil ? "\(city), \(state)" : state
                }
            }
        }
    }
}
