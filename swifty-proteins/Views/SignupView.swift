import SwiftUI

@MainActor
final class SignupViewModel: ObservableObject {
	@Published var username = ""
	@Published var password = ""
	@Published var isSecure = true
	@Published var enableFaceID = false
	var canSubmit: Bool { !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty }
	func toggleSecure() { isSecure.toggle() }
	func clearFields() {
		username = ""
		password = ""
		isSecure = true
		enableFaceID = false
	}
}

struct SignupView: View {
	@EnvironmentObject var auth: AuthStore
	@StateObject private var vm = SignupViewModel()
	@FocusState private var focusedField: Field?
	@State private var showKeyboardToolbar = false
	enum Field { case username, password }

	var body: some View {
		NavigationStack {
			ZStack {
				Color("BackgroundColor").ignoresSafeArea()
				VStack {
					Spacer()
					VStack(spacing: 32) {
						Text("Créer un compte")
							.font(.largeTitle.bold())
							.foregroundStyle(Color("OnBackgroundColor"))
						VStack(spacing: 16) {
							AuthTextField<SignupView.Field>(
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
							AuthTextField<SignupView.Field>(
								placeholder: "Mot de passe",
								text: $vm.password,
								isSecure: vm.isSecure,
								isPassword: true,
								onToggleSecure: { vm.toggleSecure() },
								focusedField: $focusedField,
								field: .password,
								submitLabel: .done,
								onSubmit: submit
							)
							Toggle(isOn: $vm.enableFaceID) { Text("Activer Face ID ?") }
								.tint(Color("AccentColor"))
								.foregroundStyle(Color("OnBackgroundColor"))
								.padding(.horizontal, 6)
							Button(action: submit) {
								Text("S’inscrire")
									.font(.headline)
									.frame(maxWidth: .infinity)
									.frame(height: 48)
									.foregroundStyle(Color("OnBackgroundColor"))
									.background(vm.canSubmit ? Color("AccentColor") : Color("AccentColor").opacity(0.5))
									.cornerRadius(12)
							}
							.disabled(!vm.canSubmit)
						}
						.padding(.horizontal, 24)
					}
					Spacer()
				}
				.tint(Color("AccentColor"))
				.scrollDismissesKeyboard(.interactively)
				.onDisappear { dismissKeyboard() }
			}
		}
		.toolbar {
			ToolbarItemGroup(placement: .keyboard) {
				Spacer()
				Button("Terminer") {
					dismissKeyboard()
					focusedField = nil
				}
			}
		}
	}

	private func submit() {
		guard vm.canSubmit else { return }
		dismissKeyboard()
		auth.signup(username: vm.username.trimmingCharacters(in: .whitespacesAndNewlines), password: vm.password, enableBiometrics: vm.enableFaceID)
		vm.clearFields()
		focusedField = nil
	}

	private func dismissKeyboard() {
		#if canImport(UIKit)
		UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
		#endif
	}
}
