import SwiftUI
import SwiftData

@main
struct swifty_proteinsApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: UserAccount.self)
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var app = AppState()

    var body: some View {
        Group {
            if let auth = app.auth {
                AppSwitchView()
                    .environmentObject(auth)
            } else {
                ProgressView()
                    .task {
                        StartupCleanup.runIfNeeded()
                        app.bootstrap(context: ctx)
                        app.bindFeedback()
                    }
            }
        }
        .feedbackOverlay(app.feedback)
        .onChange(of: scenePhase) {
            if scenePhase == .background { app.auth?.logout() }
        }
    }
}

struct AppSwitchView: View {
    @EnvironmentObject var auth: AuthStore

    @ViewBuilder
    var body: some View {
        if let session = auth.session {
            HomeView(session: session) { auth.logout() }
        } else {
            LoginView()
        }
    }
}
