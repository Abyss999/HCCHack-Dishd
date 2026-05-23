import SwiftUI
import MapKit
import UIKit

struct ResultsView: View {
    let sessionId: UUID
    @Binding var path: NavigationPath
    let onClose: () -> Void

    @EnvironmentObject var sessionVM: SessionViewModel
    @EnvironmentObject var themeStore: ThemeStore
    @Environment(\.colorScheme) var systemScheme
    var theme: AppTheme { AppTheme.current(for: themeStore.resolved(system: systemScheme)) }

    @StateObject private var vm: ResultsViewModel
    @State private var showMap = false
    @State private var mapsTarget: SessionResult?

    init(sessionId: UUID, path: Binding<NavigationPath>, onClose: @escaping () -> Void) {
        self.sessionId = sessionId
        self._path = path
        self.onClose = onClose
        self._vm = StateObject(wrappedValue: ResultsViewModel(
            sessionId: sessionId,
            sessionVM: SessionViewModel()
        ))
    }

    private let medals = ["🥇", "🥈", "🥉"]

    private var isSolo: Bool { vm.results.first?.total == 1 }

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    HStack {
                        Button {
                            onClose()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Done")
                                    .font(.system(size: 15, weight: .medium))
                            }
                            .foregroundColor(theme.primary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 16)

                    VStack(spacing: 8) {
                        Text("Results")
                            .font(.system(size: 28, weight: .black))
                            .foregroundColor(theme.text)
                        Text(isSolo ? "Your top picks" : "Your group's top picks")
                            .font(.system(size: 14))
                            .foregroundColor(theme.textSecondary)

                        if !vm.results.isEmpty {
                            Picker("View", selection: $showMap) {
                                Label("List", systemImage: "list.bullet").tag(false)
                                Label("Map", systemImage: "map").tag(true)
                            }
                            .pickerStyle(.segmented)
                            .padding(.top, 4)
                        }
                    }

                    if vm.isLoading {
                        ProgressView().tint(theme.primary).padding(40)
                    } else if vm.results.isEmpty {
                        VStack(spacing: 14) {
                            ProgressView().tint(theme.primary)
                            Text("Calculating results…")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(theme.textSecondary)
                            Text("Hang tight while everyone finishes swiping.")
                                .font(.system(size: 13))
                                .foregroundColor(theme.textTertiary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(40)
                    } else if showMap {
                        mapView
                    } else {
                        vibePickSection

                        ForEach(Array(vm.results.enumerated()), id: \.element.id) { idx, result in
                            Button {
                                mapsTarget = result
                            } label: {
                                resultRow(result: result, medal: idx < medals.count ? medals[idx] : "#\(idx+1)")
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    Task { await vm.loadFit(for: result) }
                                } label: {
                                    Label("Why this fits me", systemImage: "sparkles")
                                }
                            }
                        }
                    }

                    PrimaryButton(title: "Start New Session", variant: .secondary) {
                        onClose()
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
                .padding(.horizontal, 20)
            }
        }
        .navigationBarHidden(true)
        .task { await vm.load() }
        .confirmationDialog(
            mapsTarget?.restaurant.name ?? "Open in Maps",
            isPresented: Binding(get: { mapsTarget != nil }, set: { if !$0 { mapsTarget = nil } }),
            titleVisibility: .visible
        ) {
            Button("Open in Apple Maps") {
                if let r = mapsTarget?.restaurant { openInAppleMaps(r) }
            }
            Button("Open in Google Maps") {
                if let r = mapsTarget?.restaurant { openInGoogleMaps(r) }
            }
            Button("✨ Why this fits me") {
                if let r = mapsTarget {
                    mapsTarget = nil
                    Task { await vm.loadFit(for: r) }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: $vm.selectedFitContext) { ctx in
            PersonalizedFitSheet(context: ctx, theme: theme)
        }
    }

    @ViewBuilder
    private var vibePickSection: some View {
        if vm.isLoadingVibePick {
            HStack(spacing: 10) {
                ProgressView().tint(theme.primary)
                Text("Getting your vibe pick…")
                    .font(.system(size: 13))
                    .foregroundColor(theme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(theme.primary.opacity(0.06))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(theme.primary.opacity(0.18), lineWidth: 1)
            )
        } else if let pick = vm.vibePick {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(theme.primary.opacity(0.4))
                    .frame(width: 3)
                VStack(alignment: .leading, spacing: 6) {
                    Label("Your Vibe Pick", systemImage: "sparkles")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(theme.primary)
                    Text(pick.restaurant.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(theme.text)
                    Text(pick.narrative)
                        .font(.system(size: 13))
                        .foregroundColor(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                Spacer()
            }
            .background(theme.primary.opacity(0.06))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(theme.primary.opacity(0.18), lineWidth: 1)
            )
        }
    }

    private func openInAppleMaps(_ r: Restaurant) {
        let place = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: r.lat, longitude: r.lng))
        let item = MKMapItem(placemark: place)
        item.name = r.name
        item.openInMaps(launchOptions: [MKLaunchOptionsMapTypeKey: MKMapType.standard.rawValue])
    }

    private func openInGoogleMaps(_ r: Restaurant) {
        let name = r.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let app = URL(string: "comgooglemaps://?q=\(name)&center=\(r.lat),\(r.lng)&zoom=16")!
        let web = URL(string: "https://www.google.com/maps/search/?api=1&query=\(r.lat),\(r.lng)&query_place_id=\(r.googlePlaceId)")!
        if UIApplication.shared.canOpenURL(app) {
            UIApplication.shared.open(app)
        } else {
            UIApplication.shared.open(web)
        }
    }

    @ViewBuilder
    private var mapView: some View {
        Map(coordinateRegion: .constant(mapRegion), annotationItems: vm.results) { result in
            MapAnnotation(coordinate: CLLocationCoordinate2D(
                latitude: result.restaurant.lat,
                longitude: result.restaurant.lng
            )) {
                Button {
                    mapsTarget = result
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(vm.results.first?.id == result.id ? theme.primary : theme.textSecondary)
                            .background(Circle().fill(.white).frame(width: 22, height: 22))
                        Text(result.restaurant.name)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(theme.text)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(theme.surface.opacity(0.92))
                            .cornerRadius(4)
                            .lineLimit(1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 360)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.cardBorder, lineWidth: 1))
    }

    private var mapRegion: MKCoordinateRegion {
        guard !vm.results.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        }
        let lats = vm.results.map { $0.restaurant.lat }
        let lngs = vm.results.map { $0.restaurant.lng }
        let minLat = lats.min()!, maxLat = lats.max()!
        let minLng = lngs.min()!, maxLng = lngs.max()!
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLng + maxLng) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.5, 0.02),
            longitudeDelta: max((maxLng - minLng) * 1.5, 0.02)
        )
        return MKCoordinateRegion(center: center, span: span)
    }

    @ViewBuilder
    private func resultRow(result: SessionResult, medal: String) -> some View {
        HStack(spacing: 14) {
            Text(medal)
                .font(.system(size: 28))
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(result.restaurant.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(theme.text)
                if let address = result.restaurant.address {
                    Text(address)
                        .font(.system(size: 12))
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(1)
                }
                if let vibe = result.restaurant.vibeBlurb ?? result.restaurant.description, !vibe.isEmpty {
                    Text(vibe)
                        .font(.system(size: 11))
                        .foregroundColor(theme.textTertiary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                }
                HStack(spacing: 6) {
                    ForEach(result.restaurant.cuisineTags.prefix(2), id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 11))
                            .foregroundColor(theme.primary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(theme.chipBg)
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(result.scorePct))%")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(theme.primary)
                Text("\(result.yesCount)/\(result.total)")
                    .font(.system(size: 12))
                    .foregroundColor(theme.textSecondary)
            }
        }
        .padding(16)
        .background(theme.surface)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(theme.cardBorder, lineWidth: 1)
        )
    }
}

struct PersonalizedFitSheet: View {
    let context: PersonalizedFitContext
    let theme: AppTheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                theme.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(context.restaurantName)
                            .font(.system(size: 22, weight: .black))
                            .foregroundColor(theme.text)
                            .padding(.top, 8)

                        Divider()
                            .background(theme.textSecondary.opacity(0.12))

                        VStack(alignment: .leading, spacing: 12) {
                            fitRow(
                                icon: context.fit.dietaryMatch ? "checkmark.circle.fill" : "xmark.circle.fill",
                                color: context.fit.dietaryMatch ? .green : theme.textSecondary,
                                label: context.fit.dietaryMatch ? "Matches your dietary needs" : "May not match your dietary restrictions"
                            )
                            fitRow(
                                icon: context.fit.budgetMatch ? "checkmark.circle.fill" : "xmark.circle.fill",
                                color: context.fit.budgetMatch ? .green : theme.textSecondary,
                                label: context.fit.budgetMatch ? "Within your budget" : "Outside your usual budget range"
                            )
                            if !context.fit.cuisineOverlap.isEmpty {
                                fitRow(
                                    icon: "heart.fill",
                                    color: theme.primary,
                                    label: "Matches your interest in \(context.fit.cuisineOverlap.joined(separator: ", "))"
                                )
                            }
                        }

                        if !context.fit.cuisineOverlap.isEmpty {
                            HStack(spacing: 6) {
                                ForEach(context.fit.cuisineOverlap, id: \.self) { tag in
                                    Text(tag)
                                        .font(.system(size: 12))
                                        .foregroundColor(theme.primary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(theme.chipBg)
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(theme.chipBorder, lineWidth: 1)
                                        )
                                }
                            }
                        }

                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(theme.primary.opacity(0.4))
                                .frame(width: 3)
                            Text(context.fit.narrative)
                                .font(.system(size: 14))
                                .foregroundColor(theme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                        }
                        .background(theme.primary.opacity(0.06))
                        .cornerRadius(8)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Why this fits you")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(theme.primary)
                }
            }
        }
    }

    @ViewBuilder
    private func fitRow(icon: String, color: Color, label: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(theme.text)
        }
    }
}
