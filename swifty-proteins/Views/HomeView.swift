import SwiftUI

struct HomeView: View {
    let session: Session
    let onLogout: () -> Void

    var body: some View {
        ZStack {
            Color("BackgroundColor").ignoresSafeArea()
            VStack(spacing: 24) {
                Text("Dashboard")
                    .font(.largeTitle.bold())
                    .foregroundStyle(Color("OnBackgroundColor"))
                Text("Bienvenue \(session.username)")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(Color("OnBackgroundColor").opacity(0.8))
                Button("Se déconnecter", action: onLogout)
                    .font(.headline)
                    .frame(height: 48)
                    .frame(maxWidth: 240)
                    .foregroundStyle(Color("OnBackgroundColor"))
                    .background(Color("AccentColor"))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(24)
        }
    }
}
