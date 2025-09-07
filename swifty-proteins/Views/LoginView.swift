import SwiftUI

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var username = ""
    @Published var password = ""
    @Published var isSecure = true
    var canSubmit: Bool { !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty }
    func toggleSecure() { isSecure.toggle() }
}

struct LoginView: View {
    @EnvironmentObject var auth: AuthStore
    @StateObject private var vm = LoginViewModel()
    @FocusState private var focusedField: Field?
    @State private var showResetAlert = false
    enum Field { case username, password }

    private var normalizedUsername: String {
        vm.username.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private var canUseBiometrics: Bool {
        !normalizedUsername.isEmpty && auth.canUseBiometrics(username: normalizedUsername)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color("BackgroundColor").ignoresSafeArea()
                VStack(spacing: 28) {
                    Text("Login")
                        .font(.largeTitle.bold())
                        .foregroundStyle(Color("OnBackgroundColor"))
                    VStack(spacing: 16) {
                        AuthTextField<LoginView.Field>(
                            placeholder: "Nom d’utilisateur",
                            text: $vm.username,
                            isSecure: false,
                            isPassword: false,
                            onToggleSecure: {},
                            focusedField: $focusedField,
                            field: .username,
                            submitLabel: .next,
                            onSubmit: { focusedField = .password }
                        )
                        AuthTextField<LoginView.Field>(
                            placeholder: "Mot de passe",
                            text: $vm.password,
                            isSecure: vm.isSecure,
                            isPassword: true,
                            onToggleSecure: { vm.toggleSecure() },
                            focusedField: $focusedField,
                            field: .password,
                            submitLabel: .go,
                            onSubmit: submitPassword
                        )
                        Button(action: submitPassword) {
                            Text("Se connecter")
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .foregroundStyle(Color("OnBackgroundColor"))
                                .background(vm.canSubmit ? Color("AccentColor") : Color("AccentColor").opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .disabled(!vm.canSubmit)

                        if canUseBiometrics {
                            Button {
                                Task { auth.loginBiometrics(username: normalizedUsername) }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "faceid")
                                    Text("Se connecter avec Face ID")
                                }
                                .frame(maxWidth: .infinity, minHeight: 48)
                            }
                            .buttonStyle(.bordered)
                            .tint(Color("AccentColor"))
                        }

                        NavigationLink {
                            SignupView()
                        } label: {
                            Text("Créer un compte")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .foregroundStyle(Color("AccentColor"))
                                .background(Color("SectionColor"))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .contentShape(Rectangle())
                .onTapGesture { focusedField = nil }
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Terminer") { focusedField = nil }
                    }
                }
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(role: .destructive) {
                            showResetAlert = true
                        } label: {
                            Image(systemName: "trash")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                                .foregroundStyle(Color.red)
                                .padding(10)
                                .background(Color("SectionColor"))
                                .clipShape(Circle())
                        }
                        .padding(.bottom, 32)
                        .padding(.trailing, 24)
                    }
                }
            }
        }
        .alert("Réinitialiser l'application et les comptes associés ?", isPresented: $showResetAlert) {
            Button("Annuler", role: .cancel) {}
            Button("Supprimer", role: .destructive) {
                auth.resetAllData()
                StartupCleanup.scheduleTempCleanupOnNextLaunch()
            }
        } message: {
            Text("Comptes, secrets et caches seront supprimés définitivement.")
        }
    }

    private func submitPassword() {
        guard vm.canSubmit else { return }
        auth.loginPassword(username: normalizedUsername, password: vm.password)
    }
}
