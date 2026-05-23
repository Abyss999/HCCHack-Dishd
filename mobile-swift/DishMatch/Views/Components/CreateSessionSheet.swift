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

                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(soloMode ? "Solo Session Setup" : "Session Setup")
                        .font(.system(size: 22, weight: .black))
                        .foregroundColor(theme.text)
                    Text("Search or tap the map to set your area.")
                        .font(.system(size: 14))
                        .foregroundColor(theme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)

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
                .padding(.horizontal, 24)
                .padding(.bottom, 10)

                // Map
                TappableMapView(
                    pinnedCoordinate: pinnedCoordinate,
                    centerOn: centerOn,
                    onTap: { coord in
                        searchFocused = false
                        pinnedCoordinate = coord
                        reverseGeocode(coord)
                    }
                )
                .frame(maxHeight: .infinity)

                // Bottom strip
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(theme.primary)
                            .font(.system(size: 16))

                        if isGeocoding {
                            ProgressView().tint(theme.primary).scaleEffect(0.75)
                            Text("Finding location…")
                                .font(.system(size: 14))
                                .foregroundColor(theme.textSecondary)
                        } else if !locationLabel.isEmpty {
                            Text(locationLabel)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(theme.text)
                                .lineLimit(1)
                        } else {
                            Text("Search or tap anywhere on the map")
                                .font(.system(size: 14))
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
                                        .font(.system(size: 12))
                                }
                                Text("My Location")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(theme.primary)
                        }
                        .disabled(locationMgr.isLoading)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(theme.surface)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.cardBorder))

                    if let err = locationMgr.error {
                        Text(err).font(.system(size: 12)).foregroundColor(.red)
                    }

                    // Session settings
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
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 24)
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
        VStack(alignment: .leading, spacing: 10) {
            Text("SESSION FILTERS")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(theme.textSecondary.opacity(0.7))
                .tracking(0.6)

            // Radius slider
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Max range")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(theme.textSecondary)
                    Spacer()
                    Text("\(radiusMiles, specifier: "%.0f") mi")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.primary)
                }
                Slider(value: $sessionRadius, in: radiusMinKm...radiusMaxKm, step: 0.8)
                    .tint(theme.primary)
            }

            // Swipe limit slider — forces Top-3 reveal once every member hits this count
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Swipe limit per person")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(theme.textSecondary)
                    Spacer()
                    Text("\(Int(sessionSwipeCeiling))")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.primary)
                }
                Slider(value: $sessionSwipeCeiling, in: 3...30, step: 1)
                    .tint(theme.primary)
            }

            // Budget (multi-select)
            HStack(spacing: 6) {
                ForEach(budgetOptions, id: \.self) { b in
                    Button {
                        if sessionBudgets.contains(b) {
                            sessionBudgets.removeAll { $0 == b }
                        } else {
                            sessionBudgets.append(b)
                        }
                    } label: {
                        Text(b)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(sessionBudgets.contains(b) ? theme.primary : theme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(sessionBudgets.contains(b) ? theme.chipBg : theme.bg)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(sessionBudgets.contains(b) ? theme.chipBorder : theme.cardBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Cuisine chips
            let columns = [GridItem(.adaptive(minimum: 88), spacing: 6)]
            LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
                ForEach(cuisineOptions, id: \.self) { c in
                    Button {
                        if sessionCuisines.contains(c) {
                            sessionCuisines.removeAll { $0 == c }
                        } else {
                            sessionCuisines.append(c)
                        }
                    } label: {
                        Text(c)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(sessionCuisines.contains(c) ? theme.primary : theme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .background(sessionCuisines.contains(c) ? theme.chipBg : theme.bg)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(sessionCuisines.contains(c) ? theme.chipBorder : theme.cardBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(theme.surface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.cardBorder))
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
