import SwiftUI

struct CompactSessionView: View {
    let token: String
    var onSessionCreated: (Session) -> Void
    var onJoinSession: (Session) -> Void
    var onSendMessage: (Session) -> Void

    @State private var joinCode = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var createdSession: Session?

    private var service: MessageSessionService { MessageSessionService(token: token) }
    private let primaryColor = Color(red: 0.851, green: 0.467, blue: 0.341)

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "fork.knife.circle.fill")
                    .foregroundColor(primaryColor)
                    .font(.system(size: 22))
                Text("DishMatch")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Divider()

            if let session = createdSession {
                VStack(spacing: 12) {
                    Text("Session created!")
                        .font(.system(size: 14, weight: .semibold))
                    Text(session.code)
                        .font(.system(size: 32, weight: .black, design: .monospaced))
                        .foregroundColor(primaryColor)
                    HStack(spacing: 10) {
                        Button("Send to Chat") { onSendMessage(session) }
                            .buttonStyle(.borderedProminent)
                            .tint(primaryColor)
                        Button("Start Swiping") { onSessionCreated(session) }
                            .buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal, 16)
            } else {
                Button {
                    Task { await createSession() }
                } label: {
                    Label("New Session", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(primaryColor)
                .padding(.horizontal, 16)
                .disabled(isLoading)

                HStack(spacing: 10) {
                    TextField("CODE", text: $joinCode)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .textCase(.uppercase)
                        .autocapitalization(.allCharacters)
                        .keyboardType(.asciiCapable)
                        .frame(width: 90)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .onChange(of: joinCode) { v in
                            if v.count > 4 { joinCode = String(v.prefix(4)) }
                        }

                    Button("Join") {
                        Task { await joinSession() }
                    }
                    .buttonStyle(.bordered)
                    .disabled(joinCode.count < 4 || isLoading)
                }
                .padding(.horizontal, 16)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12))
                    .foregroundColor(.red)
                    .padding(.horizontal, 16)
            }

            if isLoading {
                ProgressView().padding(.vertical, 4)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func createSession() async {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            // Default Houston coordinates; real app would use CLLocationManager
            let session = try await service.createSession(lat: 29.7604, lng: -95.3698)
            createdSession = session
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func joinSession() async {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            let session = try await service.joinSession(code: joinCode)
            onJoinSession(session)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
