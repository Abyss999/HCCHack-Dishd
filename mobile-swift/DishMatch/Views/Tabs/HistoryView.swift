import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var themeStore: ThemeStore
    @EnvironmentObject var authStore: AuthStore
    @Environment(\.colorScheme) var systemScheme
    var theme: AppTheme { AppTheme.current(for: themeStore.resolved(system: systemScheme)) }

    @StateObject private var sessionVM: SessionViewModel
    @StateObject private var vm: HistoryViewModel
    @State private var activeSession: Session?
    @State private var pendingDelete: Session?
    @State private var pendingClearAll = false
    @State private var filter: HistoryFilter = .all
    @State private var dateFilter: DateFilter = .all

    enum HistoryFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case lobby = "Lobby"
        case swiping = "Swiping"
        case results = "Results"
        case matched = "Matched"
        case solo = "Solo"
        case group = "Group"
        var id: String { rawValue }
    }

    enum DateFilter: String, CaseIterable, Identifiable {
        case all = "Any time"
        case today = "Today"
        case week = "Past week"
        case month = "Past month"
        var id: String { rawValue }

        func cutoff(now: Date = Date()) -> Date? {
            let cal = Calendar.current
            switch self {
            case .all: return nil
            case .today: return cal.startOfDay(for: now)
            case .week: return cal.date(byAdding: .day, value: -7, to: now)
            case .month: return cal.date(byAdding: .month, value: -1, to: now)
            }
        }
    }

    private var filteredSessions: [Session] {
        let cutoff = dateFilter.cutoff()
        return vm.sessions.filter { s in
            let statusOK: Bool = {
                switch filter {
                case .all: return true
                case .lobby: return s.status == .lobby
                case .swiping: return s.status == .swiping
                case .results: return s.status == .results
                case .matched: return s.status == .matched
                case .solo: return s.soloMode == true
                case .group: return s.soloMode != true
                }
            }()
            let dateOK = cutoff.map { s.createdAt >= $0 } ?? true
            return statusOK && dateOK
        }
    }

    init() {
        let svm = SessionViewModel()
        _sessionVM = StateObject(wrappedValue: svm)
        _vm = StateObject(wrappedValue: HistoryViewModel(sessionVM: svm))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.bg.ignoresSafeArea()
                content
            }
            .navigationBarHidden(true)
        }
        .task { await vm.load() }
        .refreshable { await vm.load() }
        .fullScreenCover(item: $activeSession) { session in
            SessionNavigator(sessionId: session.id, sessionVM: sessionVM, isSolo: session.soloMode == true)
                .environmentObject(authStore)
                .environmentObject(themeStore)
        }
        .onChange(of: activeSession) { s in
            if s == nil { Task { await vm.load() } }
        }
        .confirmationDialog(
            "Delete this session?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete for everyone", role: .destructive) {
                if let s = pendingDelete { Task { await vm.delete(s) } }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("As the host, deleting removes this session for all members.")
        }
        .confirmationDialog(
            clearAllTitle,
            isPresented: $pendingClearAll,
            titleVisibility: .visible
        ) {
            Button("Clear \(filteredSessions.count)", role: .destructive) {
                Task { await vm.clearAll(filteredSessions) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Sessions you host will be deleted for everyone; others you'll just leave.")
        }
        .alert("Error", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("OK") { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    @ViewBuilder private var content: some View {
        VStack(spacing: 12) {
            header
            filterBar
            if vm.isLoading && vm.sessions.isEmpty {
                Spacer(); ProgressView().tint(theme.primary); Spacer()
            } else if filteredSessions.isEmpty {
                Spacer(); emptyState; Spacer()
            } else {
                List {
                    ForEach(filteredSessions) { session in
                        row(session)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if vm.isHost(of: session) {
                                    Button(role: .destructive) {
                                        pendingDelete = session
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                Button {
                                    Task { await vm.leave(session) }
                                } label: {
                                    Label("Leave", systemImage: "rectangle.portrait.and.arrow.right")
                                }
                                .tint(.orange)
                            }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .refreshable { await vm.load() }
            }
        }
    }

    private var filterBar: some View {
        VStack(spacing: 6) {
            HStack {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(HistoryFilter.allCases) { f in
                            chip(title: f.rawValue, isSelected: filter == f) { filter = f }
                        }
                    }
                }
                if !filteredSessions.isEmpty {
                    Button {
                        pendingClearAll = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.red)
                            .padding(8)
                            .background(theme.surface)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.cardBorder, lineWidth: 1))
                    }
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(DateFilter.allCases) { d in
                        chip(title: d.rawValue, isSelected: dateFilter == d) { dateFilter = d }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func chip(title: String, isSelected: Bool, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isSelected ? theme.primary : theme.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? theme.chipBg : theme.surface)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? theme.chipBorder : theme.cardBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var clearAllTitle: String {
        let parts: [String] = [
            filter == .all ? nil : filter.rawValue.lowercased(),
            dateFilter == .all ? nil : dateFilter.rawValue.lowercased()
        ].compactMap { $0 }
        if parts.isEmpty {
            return "Clear all \(filteredSessions.count) sessions?"
        }
        return "Clear \(filteredSessions.count) \(parts.joined(separator: " / ")) sessions?"
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("History")
                .font(.system(size: 28, weight: .black))
                .foregroundColor(theme.text)
            Text("Tap a session to re-open. Swipe to leave or delete.")
                .font(.system(size: 13))
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 24)
        .padding(.bottom, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 36))
                .foregroundColor(theme.textTertiary)
            Text("No past sessions yet")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(theme.textSecondary)
            Text("Create a session from Home to get started.")
                .font(.system(size: 12))
                .foregroundColor(theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }

    @ViewBuilder
    private func row(_ session: Session) -> some View {
        let isHost = vm.isHost(of: session)
        Button {
            activeSession = session
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(statusColor(session.status))
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(session.code)
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundColor(theme.primary)
                        if session.soloMode == true {
                            tag("SOLO")
                        }
                        if isHost {
                            tag("HOST")
                        }
                    }
                    Text(session.locationLabel ?? "No location")
                        .font(.system(size: 12))
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(statusLabel(session.status))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(statusColor(session.status))
                    Text(shortDate(session.createdAt))
                        .font(.system(size: 11))
                        .foregroundColor(theme.textSecondary)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(theme.surface)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.cardBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .contextMenu {
            if isHost {
                Button(role: .destructive) {
                    pendingDelete = session
                } label: {
                    Label("Delete session", systemImage: "trash")
                }
            }
            Button(role: .destructive) {
                Task { await vm.leave(session) }
            } label: {
                Label(isHost ? "Leave (transfer host)" : "Leave session", systemImage: "rectangle.portrait.and.arrow.right")
            }
        }
    }

    private func tag(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(theme.textSecondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(theme.chipBg)
            .cornerRadius(4)
    }

    private func statusColor(_ status: SessionStatus) -> Color {
        switch status {
        case .lobby: return theme.textSecondary
        case .swiping: return theme.primary
        case .results: return .blue
        case .matched: return .green
        }
    }

    private func statusLabel(_ status: SessionStatus) -> String {
        switch status {
        case .lobby: return "Lobby"
        case .swiping: return "Swiping"
        case .results: return "Results"
        case .matched: return "Matched"
        }
    }

    private func shortDate(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return fmt.string(from: date)
    }
}
