import SwiftUI
import UIKit

/*
	barre d'info atome plus detaillee car PeriodicTable.json chargé
*/
struct AtomInfoBar: View {
    let atom: LigandData.Atom
    var onClose: () -> Void
	@StateObject private var webSheetController = WebSheetController()

    @State private var expanded = false

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial, in: Capsule())
    }

    private func item(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.footnote.weight(.semibold))
        }
        .padding(8)
        .background(Color("BackgroundColor").opacity(0.6), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    var body: some View {
        let info = PeriodicTable.shared.info(for: atom.symbol)
        let color = PeriodicTable.shared.color(for: atom.symbol) ?? UIColor.systemGray
        let num = info?.number
        let mass = info?.atomicMass
        let vdw = info?.vdwRadiusAngstrom
        let en = info?.electronegativityPauling
        let ea = info?.electronAffinity
        let dens = info?.density
        let melt = info?.melt
        let boil = info?.boil
        let cat = info?.category
        let grp = info?.group
        let per = info?.period
        let blk = info?.block
        let app = info?.appearance
        let shells = info?.shells
        let cfg = info?.electronConfiguration
        let cfgSem = info?.electronConfigurationSemantic
        let firstIE = info?.ionizationEnergies?.first
        let maxIE = info?.ionizationEnergies?.max()
        let imgURL = info?.imageURL.flatMap(URL.init(string:))
        let srcURL = info?.sourceURL.flatMap(URL.init(string:))
        let summary = info?.summary

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color(color))
                    .frame(width: 18, height: 18)
                    .overlay(
                        Text(num != nil ? "\(num!)" : "")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.9))
                    )
                Text("\(atom.symbol)\(info?.name != nil ? " · \(info!.name!)" : "")")
                    .font(.headline)
                Spacer(minLength: 0)
                Button(role: .cancel) { onClose() } label: {
                    Image(systemName: "xmark")
                        .imageScale(.small)
                        .padding(6)
                        .background(.ultraThinMaterial, in: Circle())
                }
            }

            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Text("x: \(atom.x, specifier: "%.3f")")
                    Text("y: \(atom.y, specifier: "%.3f")")
                    Text("z: \(atom.z, specifier: "%.3f")")
                }
                .font(.caption)
                if atom.charge != 0 { chip("Charge \(atom.charge)") }
            }

            if imgURL != nil || app != nil {
                HStack(spacing: 10) {
                    if let u = imgURL {
                        AsyncImage(url: u) { phase in
                            switch phase {
                            case .success(let i): i.resizable().scaledToFill()
                            default: Color.gray.opacity(0.2)
                            }
                        }
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    if let a = app, !a.isEmpty {
                        Text(a.capitalized)
                            .font(.caption)
                            .lineLimit(2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
            }

			FlowLayout(spacing: 8) {
				if let m = mass { item("Masse atomique", String(format: "%.3f u", m)) }
				if let r = vdw { item("Rayon VdW", String(format: "%.2f Å", r)) }
				if let e = en { item("Électronégativité (χ)", String(format: "%.2f", e)) }
				if let a = ea { item("Affinité électronique", String(format: "%.2f kJ/mol", a)) }
				if let d = dens { item("Densité", String(format: "%.3f g/cm³", d)) }
				if let t = melt { item("Fusion", String(format: "%.0f K", t)) }
				if let t = boil { item("Ébullition", String(format: "%.0f K", t)) }
				if let c = cat, !c.isEmpty { item("Catégorie", c.capitalized) }
				if let g = grp { item("Groupe", "\(g)") }
				if let p = per { item("Période", "\(p)") }
				if let b = blk, !b.isEmpty { item("Bloc", b.uppercased()) }
				if let s = shells, !s.isEmpty { item("Couches", s.map(String.init).joined(separator: " · ")) }
				if let c = cfg, !c.isEmpty { item("Configuration e⁻", c.replacingOccurrences(of: " ", with: "")) }
				if let cs = cfgSem, !cs.isEmpty { item("Configuration (sem.)", cs) }
				if let f = firstIE { item("1ère ionisation", String(format: "%.0f kJ/mol", f)) }
				if let mx = maxIE { item("Ionisation max", String(format: "%.0f kJ/mol", mx)) }
			}
			.padding(.vertical, 2)

            if let s = summary, !s.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Résumé").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text(s)
                        .font(.footnote)
                        .lineLimit(expanded ? nil : 1)
                    HStack {
                        Spacer()
                        Button(expanded ? "Réduire" : "Lire plus") { withAnimation(.snappy) { expanded.toggle() } }
                            .font(.caption.weight(.semibold))
                            .buttonStyle(.borderedProminent)
                    }
                }
            }

			HStack {
				if let url = srcURL {
					Button {
						webSheetController.open(url)
					} label: {
						Label("Source", systemImage: "safari")
							.font(.caption.weight(.semibold))
							.padding(.horizontal, 10)
							.padding(.vertical, 6)
							.background(.ultraThinMaterial, in: Capsule())
					}
				}
				Spacer(minLength: 0)
			}
			.sheet(isPresented: $webSheetController.isPresented) {
				if let url = webSheetController.url {
					SafariView(url: url)
				}
			}
        }
        .padding(10)
        .background(Color("SectionColor"), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
