import SwiftUI

struct LoginView: View {
    @Binding var path: NavigationPath

    @EnvironmentObject var themeStore: ThemeStore
    @Environment(\.colorScheme) var systemScheme
    var theme: AppTheme { AppTheme.current(for: themeStore.resolved(system: systemScheme)) }

    @StateObject private var vm = AuthViewModel()
    @State private var email = ""
    @State private var password = ""
    @State private var showError = false

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "fork.knife.circle.fill")
                            .font(.system(size: 56))
                            .foregroundColor(theme.primary)
                        Text("DishMatch")
                            .font(.system(size: 32, weight: .black))
                            .foregroundColor(theme.text)
                        Text("Find where everyone wants to eat")
                            .font(.system(size: 15))
                            .foregroundColor(theme.textSecondary)
                    }
                    .padding(.top, 60)

                    // Form
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Email").font(.system(size: 13, weight: .medium)).foregroundColor(theme.textSecondary)
                            TextField("you@example.com", text: $email)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .padding(14)
                                .background(theme.inputBg)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.inputBorder, lineWidth: 1))
                                .cornerRadius(10)
                                .foregroundColor(theme.text)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Password").font(.system(size: 13, weight: .medium)).foregroundColor(theme.textSecondary)
                            SecureField("••••••••", text: $password)
                                .padding(14)
                                .background(theme.inputBg)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.inputBorder, lineWidth: 1))
                                .cornerRadius(10)
                                .foregroundColor(theme.text)
                        }

                        PrimaryButton(title: "Log In", isLoading: vm.isLoading) {
                            Task { await vm.login(email: email, password: password) }
                        }
                    }
                    .padding(.horizontal, 24)

                    Button {
                        path.append(AuthRoute.signup)
                    } label: {
                        HStack(spacing: 4) {
                            Text("Don't have an account?").foregroundColor(theme.textSecondary)
                            Text("Sign up").foregroundColor(theme.primary).fontWeight(.semibold)
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
}
