import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authStore: AuthStore
    @EnvironmentObject var themeStore: ThemeStore
    @Environment(\.colorScheme) var systemScheme
    var theme: AppTheme { AppTheme.current(for: themeStore.resolved(system: systemScheme)) }

    @StateObject private var vm = ProfileViewModel()
    @State private var showSaveConfirm = false

    private let dietaryOptions  = ["Vegetarian", "Vegan", "Gluten-free", "Dairy-free", "Nut-free", "Halal", "Kosher", "Pescatarian"]
    private let cuisineOptions  = [
        "Italian", "Mexican", "American", "Chinese", "Japanese", "Thai",
        "Korean", "Vietnamese", "Indian", "Mediterranean", "Greek",
        "French", "Spanish", "Middle Eastern", "BBQ", "Burgers",
        "Pizza", "Sushi", "Seafood", "Steakhouse", "Brunch", "Bakery",
        "Cafe", "Dessert", "Vegan", "Vegetarian"
    ]
    private let budgetOptions   = ["$", "$$", "$$$", "$$$$"]
    private let distanceMinKm: Double = 1.6
    private let distanceMaxKm: Double = 80.0

    private var distanceMiles: Double { vm.maxDistanceKm / 1.609 }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.bg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        headerCard
                        preferencesCard
                        appearanceCard
                        actions
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onChange(of: vm.saveSuccess) { success in
            if success { showSaveConfirm = true; vm.saveSuccess = false }
        }
        .alert("Saved!", isPresented: $showSaveConfirm) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your preferences have been updated.")
        }
    }

    // MARK: - Header

    @ViewBuilder private var headerCard: some View {
        if let user = authStore.user {
            VStack(spacing: 12) {
                ZStack {
                    AvatarView(name: user.name, userId: user.id, size: 80)
                    Circle()
                        .stroke(theme.primary.opacity(0.35), lineWidth: 2.5)
                        .frame(width: 88, height: 88)
                }
                .padding(.top, 6)

                VStack(spacing: 2) {
                    Text(user.name)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(theme.text)
                    Text(user.email)
                        .font(.system(size: 13))
                        .foregroundColor(theme.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                ZStack(alignment: .top) {
                    theme.surface
                    Rectangle()
                        .fill(theme.primary.opacity(0.4))
                        .frame(height: 3)
                }
            )
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(theme.cardBorder, lineWidth: 1))
        }
    }

    // MARK: - Preferences card

    @ViewBuilder private var preferencesCard: some View {
        cardContainer {
            sectionTitle("PREFERENCES")

            section(label: "Dietary restrictions") {
                chipGrid(options: dietaryOptions, selected: vm.dietaryRestrictions) { item in
                    vm.toggle(item, in: &vm.dietaryRestrictions)
                }
            }

            divider

            section(label: "Cuisines you like") {
                chipGrid(options: cuisineOptions, selected: vm.cuisinePreferences) { item in
                    vm.toggle(item, in: &vm.cuisinePreferences)
                }
            }

            divider

            section(label: "Budget") {
                HStack(spacing: 8) {
                    ForEach(budgetOptions, id: \.self) { b in
                        budgetChip(b)
                    }
                }
            }

            divider

            section(label: "Max distance") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Range")
                            .font(.system(size: 13))
                            .foregroundColor(theme.textSecondary)
                        Spacer()
                        Text("\(distanceMiles, specifier: "%.0f") mi")
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundColor(theme.primary)
                    }
                    Slider(value: $vm.maxDistanceKm, in: distanceMinKm...distanceMaxKm, step: 0.8)
                        .tint(theme.primary)
                    Text("Used as the default radius when you start a new session. Each session can override it.")
                        .font(.system(size: 11))
                        .foregroundColor(theme.textTertiary)
                }
            }
        }
    }

    // MARK: - Appearance

    @ViewBuilder private var appearanceCard: some View {
        cardContainer {
            sectionTitle("APPEARANCE")
            HStack(spacing: 8) {
                ForEach(ThemeStore.Mode.allCases, id: \.self) { mode in
                    let isSelected = themeStore.mode == mode
                    Button { themeStore.setMode(mode) } label: {
                        Text(mode.rawValue.capitalized)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(isSelected ? theme.primary : theme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(isSelected ? theme.chipBg : theme.bg)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSelected ? theme.chipBorder : theme.cardBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Actions

    @ViewBuilder private var actions: some View {
        VStack(spacing: 12) {
            PrimaryButton(title: "Save Preferences", isLoading: vm.isSaving) {
                Task { await vm.savePreferences() }
            }
            PrimaryButton(title: "Log Out", variant: .ghost) {
                authStore.logout()
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func cardContainer<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            content()
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
    private func section<Content: View>(label: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(theme.text)
            content()
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(theme.textSecondary.opacity(0.12))
            .frame(height: 1)
    }

    private func budgetChip(_ b: String) -> some View {
        let isSelected = vm.budgetRanges.contains(b)
        return Button {
            vm.toggle(b, in: &vm.budgetRanges)
        } label: {
            Text(b)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isSelected ? theme.primary : theme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? theme.chipBg : theme.bg)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSelected ? theme.chipBorder : theme.cardBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func chipGrid(options: [String], selected: [String], onTap: @escaping (String) -> Void) -> some View {
        let columns = [GridItem(.adaptive(minimum: 110), spacing: 8)]
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(options, id: \.self) { item in
                let isSelected = selected.contains(item)
                Button { onTap(item) } label: {
                    Text(item)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(isSelected ? theme.primary : theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(isSelected ? theme.chipBg : theme.bg)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSelected ? theme.chipBorder : theme.cardBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
