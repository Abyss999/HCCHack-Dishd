import SwiftUI

struct SignupView: View {
    @Binding var path: NavigationPath

    @EnvironmentObject var themeStore: ThemeStore
    @Environment(\.colorScheme) var systemScheme
    var theme: AppTheme { AppTheme.current(for: themeStore.resolved(system: systemScheme)) }

    @StateObject private var vm = AuthViewModel()
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var showError = false

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 32) {
                    VStack(spacing: 8) {
                        Text("Create Account")
                            .font(.system(size: 28, weight: .black))
                            .foregroundColor(theme.text)
                        Text("Join DishMatch and never argue about food again")
                            .font(.system(size: 14))
                            .foregroundColor(theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 48)

                    VStack(spacing: 16) {
                        inputField(label: "Name", placeholder: "Your name", binding: $name)
                            .textContentType(.name)

                        inputField(label: "Email", placeholder: "you@example.com", binding: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Password").font(.system(size: 13, weight: .medium)).foregroundColor(theme.textSecondary)
                            SecureField("Min. 8 characters", text: $password)
                                .padding(14)
                                .background(theme.inputBg)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.inputBorder, lineWidth: 1))
                                .cornerRadius(10)
                                .foregroundColor(theme.text)
                        }

                        PrimaryButton(title: "Create Account", isLoading: vm.isLoading,
                                      isDisabled: name.isEmpty || email.isEmpty || password.count < 8) {
                            Task { await vm.signup(email: email, password: password, name: name) }
                        }
                    }
                    .padding(.horizontal, 24)

                    Button { path.removeLast() } label: {
                        HStack(spacing: 4) {
                            Text("Already have an account?").foregroundColor(theme.textSecondary)
                            Text("Log in").foregroundColor(theme.primary).fontWeight(.semibold)
                        }
                        .font(.system(size: 14))
                    }

                    Spacer(minLength: 40)
                }
            }
        }
        .navigationBarHidden(true)
        .onChange(of: vm.errorMessage) { msg in
            if msg != nil { showError = true }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private func inputField(label: String, placeholder: String, binding: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 13, weight: .medium)).foregroundColor(theme.textSecondary)
            TextField(placeholder, text: binding)
                .padding(14)
                .background(theme.inputBg)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.inputBorder, lineWidth: 1))
                .cornerRadius(10)
                .foregroundColor(theme.text)
        }
    }
}
