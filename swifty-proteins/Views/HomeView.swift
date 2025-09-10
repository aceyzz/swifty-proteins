import SwiftUI

struct HomeView: View {
    let session: Session
    let onLogout: () -> Void
    @StateObject private var vm = LigandsViewModel()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(vm.filtered, id: \.self) { ligand in
                        NavigationLink(value: ligand) {
                            LigandRow(name: ligand)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Ligands")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Se déconnecter", role: .destructive) {
                        dismissKeyboard()
                        onLogout()
                    }
                }
            }
            .searchable(text: $vm.query, prompt: "Rechercher un ligand")
            .overlay {
                Group {
                    if vm.isLoading && vm.items.isEmpty {
                        ProgressView("Chargement…")
                    } else if let err = vm.error {
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text(err).font(.footnote.weight(.semibold))
                        }
                        .foregroundStyle(.red)
                    }
                }
                .padding()
                .allowsHitTesting(false)
            }
            .navigationDestination(for: String.self) { LigandDetailView(ligand: $0) }
            .background(Color("BackgroundColor").ignoresSafeArea())
            .tint(Color("AccentColor"))
            .scrollDismissesKeyboard(.immediately)
            .onDisappear { dismissKeyboard() }
        }
        .task { await vm.load() }
    }

    private func dismissKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
}

struct LigandDetailView: View {
    let ligand: String
    var body: some View {
        VStack(spacing: 16) {
            Text(ligand).font(.largeTitle)
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("BackgroundColor").ignoresSafeArea())
        .navigationTitle(ligand)
        .navigationBarTitleDisplayMode(.inline)
    }
}
