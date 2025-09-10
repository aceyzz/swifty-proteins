import SwiftUI

struct LigandDetailView: View {
	let ligand: String
	@StateObject private var feedback = FeedbackCenter()
	@State private var isLoading = true
	@State private var molecules: [SDFMolecule] = []
	@State private var errorText: String?

	private let repo = SDFRepository()

	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			if isLoading {
				ProgressView("Téléchargement SDF…")
					.frame(maxWidth: .infinity, alignment: .center)
			} else if let errorText {
				VStack(spacing: 10) {
					Image(systemName: "exclamationmark.triangle.fill")
					Text(errorText).font(.footnote.weight(.semibold))
				}
				.foregroundStyle(.red)
				.frame(maxWidth: .infinity, alignment: .center)
			} else {
				ForEach(molecules.indices, id: \.self) { idx in
					let mol = molecules[idx]
					VStack(alignment: .leading, spacing: 10) {
						Text("Titre: \(mol.title)").font(.headline)
						Text("Programme: \(mol.program)").font(.subheadline)
						Text("Commentaire: \(mol.comment)").font(.subheadline)
						Text("Atomes: \(mol.atoms.count)  |  Liaisons: \(mol.bonds.count)").font(.subheadline)
						if !mol.atoms.isEmpty {
							Text("Liste des atomes:").font(.subheadline.weight(.semibold))
							ScrollView(.horizontal) {
								HStack(spacing: 8) {
									ForEach(mol.atoms.indices, id: \.self) { i in
										let a = mol.atoms[i]
										VStack(alignment: .leading) {
											Text("\(i+1). \(a.symbol)")
											Text("x: \(a.x), y: \(a.y), z: \(a.z)")
											if a.charge != 0 {
												Text("Charge: \(a.charge)")
											}
										}
										.font(.caption)
										.padding(6)
										.background(Color.gray.opacity(0.1))
										.cornerRadius(6)
									}
								}
							}
							.frame(maxHeight: 80)
						}
						if !mol.bonds.isEmpty {
							Text("Liste des liaisons:").font(.subheadline.weight(.semibold))
							ScrollView(.horizontal) {
								HStack(spacing: 8) {
									ForEach(mol.bonds.indices, id: \.self) { i in
										let b = mol.bonds[i]
										VStack(alignment: .leading) {
											Text("\(i+1). Atomes: \(b.a1)-\(b.a2)")
											Text("Ordre: \(b.order)")
										}
										.font(.caption)
										.padding(6)
										.background(Color.blue.opacity(0.1))
										.cornerRadius(6)
									}
								}
							}
							.frame(maxHeight: 60)
						}
						if !mol.properties.isEmpty {
							Text("Propriétés (\(mol.properties.count))").font(.subheadline.weight(.semibold))
							ScrollView {
								VStack(alignment: .leading, spacing: 6) {
									ForEach(mol.properties.sorted(by: { $0.key < $1.key }), id: \.key) { k, v in
										Text("\(k): \(v)").font(.caption).foregroundStyle(.secondary)
									}
								}
							}
							.frame(maxHeight: 160)
						}
					}
					.padding(.vertical, 8)
					Divider()
				}
				Spacer()
			}
		}
		.padding()
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(Color("BackgroundColor").ignoresSafeArea())
		.navigationTitle(ligand)
		.navigationBarTitleDisplayMode(.inline)
		.feedbackOverlay(feedback)
		.task { await load() }
	}

	private func load() async {
		isLoading = true
		errorText = nil
		do {
			let sdf = try await repo.fetchLigand(id: ligand)
			self.molecules = sdf.molecules
			self.isLoading = false
		} catch {
			self.isLoading = false
			if let e = error as? SDFFetchError {
				self.errorText = e.localizedDescription
			} else {
				self.errorText = error.localizedDescription
			}
			feedback.show(self.errorText ?? "Erreur inconnue", style: .error)
		}
	}
}
