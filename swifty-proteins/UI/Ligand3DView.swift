import SwiftUI
import SceneKit
import UIKit

struct Ligand3DView: View {
    let molecule: LigandData.Molecule
    var onStatus: ((String, FeedbackStyle) -> Void)? = nil

    @State private var selectedAtomIndex: Int?
    @State private var requestShare = false
    @State private var shareURL: URL?
    @State private var presentShare = false
    @State private var showFullscreen = false
    @State private var style: GeometryStyle = .sphere

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Menu {
                    Picker("Forme", selection: $style) {
                        ForEach(GeometryStyle.allCases) { s in
                            Text(s.title).tag(s)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "cube.transparent")
                        Text(style.title)
                    }
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                }

                Button {
                    requestShare = true
                } label: {
                    Label("Partager", systemImage: "square.and.arrow.up")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                .accessibilityLabel("Partager l’aperçu actuel")

                Button {
                    NotificationCenter.default.post(name: Ligand3DSceneView.resetCameraNote, object: nil)
                } label: {
                    Label("Reset", systemImage: "gobackward")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                }

                Spacer(minLength: 0)

                Button {
                    showFullscreen = true
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .imageScale(.medium)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                .accessibilityLabel("Plein écran")
            }

            Ligand3DSceneView(
                molecule: molecule,
                selectedAtomIndex: $selectedAtomIndex,
                requestShare: $requestShare,
                style: style
            ) { url in
                shareURL = url
                requestShare = false
                if url != nil { presentShare = true }
            }
            .frame(height: 360)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .sheet(isPresented: $presentShare, onDismiss: { shareURL = nil }) {
                if let url = shareURL {
                    ActivityShareSheet(items: [url])
                        .ignoresSafeArea()
                }
            }
            .fullScreenCover(isPresented: $showFullscreen) {
                FullscreenLigand3D(molecule: molecule, style: style)
                    .ignoresSafeArea()
            }

            if let idx = selectedAtomIndex {
                AtomInfoBar(atom: molecule.atoms[idx]) {
                    selectedAtomIndex = nil
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: selectedAtomIndex)
        .onAppear { onStatus?("Rendu 3D prêt", .success) }
    }
}

private struct AtomInfoBar: View {
    let atom: LigandData.Atom
    var onClose: () -> Void
    var body: some View {
        HStack(spacing: 10) {
            let info = PeriodicTable.shared.info(for: atom.symbol)
            Text("\(atom.symbol)\(info?.name != nil ? " · \(info!.name!)" : "")")
                .font(.headline)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            HStack(spacing: 8) {
                Text("x: \(atom.x, specifier: "%.3f")")
                Text("y: \(atom.y, specifier: "%.3f")")
                Text("z: \(atom.z, specifier: "%.3f")")
            }
            .font(.caption)
            if atom.charge != 0 {
                Text("Charge: \(atom.charge)")
                    .font(.caption)
            }
            Spacer(minLength: 0)
            Button(role: .cancel) { onClose() } label: {
                Image(systemName: "xmark")
                    .imageScale(.small)
                    .padding(6)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
        .padding(10)
        .background(Color("SectionColor"), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

enum ImageShareWriter {
    static func writePNG(_ image: UIImage) -> URL? {
        guard let data = image.pngData() else { return nil }
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("share", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let url = dir.appendingPathComponent("ligand-\(UUID().uuidString).png")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch { return nil }
    }

    static func watermark(_ image: UIImage, text: String) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { _ in
            image.draw(at: .zero)
            let margin: CGFloat = 16
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: max(12, min(image.size.width, image.size.height) * 0.022), weight: .semibold),
                .foregroundColor: UIColor.white.withAlphaComponent(0.9),
                .shadow: {
                    let s = NSShadow()
                    s.shadowBlurRadius = 4
                    s.shadowColor = UIColor.black.withAlphaComponent(0.55)
                    s.shadowOffset = CGSize(width: 0, height: 2)
                    return s
                }()
            ]
            let attributed = NSAttributedString(string: text, attributes: attributes)
            let size = attributed.size()
            let point = CGPoint(x: image.size.width - size.width - margin, y: image.size.height - size.height - margin)
            attributed.draw(at: point)
        }
    }
}

struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct FullscreenLigand3D: View {
    let molecule: LigandData.Molecule
    let style: GeometryStyle
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Int?
    @State private var req = false
    var body: some View {
        ZStack {
            Color.black.opacity(0.9).ignoresSafeArea()
            Ligand3DSceneView(molecule: molecule, selectedAtomIndex: $selected, requestShare: $req, style: style) { _ in }
                .padding()
            .ignoresSafeArea(.container, edges: .bottom)
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24, weight: .bold))
                            .padding(12)
                    }
                    .padding(.trailing, 12)
                    .padding(.top, 12)
                    .padding(.top, (UIApplication.shared.connectedScenes
                        .compactMap { ($0 as? UIWindowScene)?.keyWindow }
                        .first?.safeAreaInsets.top ?? 0))
                    Spacer()
                }
            }
            .ignoresSafeArea(.container, edges: .top)
        }
    }
}

struct Ligand3DSceneView: UIViewRepresentable {
    static let resetCameraNote = Notification.Name("Ligand3DSceneView.resetCamera")

    let molecule: LigandData.Molecule
    @Binding var selectedAtomIndex: Int?
    @Binding var requestShare: Bool
    var style: GeometryStyle = .sphere
    let onShareReady: (URL?) -> Void

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.scene = SCNScene()
        view.allowsCameraControl = true
        view.defaultCameraController.interactionMode = .orbitTurntable
        view.antialiasingMode = .multisampling4X
        view.pointOfView = context.coordinator.makeCameraNode()
        view.autoenablesDefaultLighting = false
        view.isJitteringEnabled = true
        view.isTemporalAntialiasingEnabled = true
        context.coordinator.configure(view: view, with: molecule, style: style)
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
        NotificationCenter.default.addObserver(context.coordinator, selector: #selector(Coordinator.resetCamera), name: Self.resetCameraNote, object: nil)
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.updateSelectionBinding = { idx in
            selectedAtomIndex = idx
        }
        if context.coordinator.currentStyle != style {
            context.coordinator.rebuild(style: style)
        }
        if requestShare {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                guard let img = context.coordinator.safeSnapshot() else {
                    onShareReady(nil)
                    return
                }
                let marked = ImageShareWriter.watermark(img, text: "cedmulle - 42swifty-companion")
                let url = ImageShareWriter.writePNG(marked)
                onShareReady(url)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(molecule: molecule)
    }

    final class Coordinator: NSObject {
        private(set) var molecule: LigandData.Molecule
        private weak var scnView: SCNView?
        private let root = SCNNode()
        private let atomRadius: CGFloat = 0.22
        private let bondRadius: CGFloat = 0.07
        private var materialCache: [String: SCNMaterial] = [:]
        private lazy var bondMaterial: SCNMaterial = {
            let m = SCNMaterial()
            m.diffuse.contents = UIColor(white: 0.75, alpha: 1.0)
            m.lightingModel = .physicallyBased
            m.metalness.contents = 0.1
            m.roughness.contents = 0.4
            return m
        }()
        var updateSelectionBinding: ((Int?) -> Void)?
        var currentStyle: GeometryStyle = .sphere

        init(molecule: LigandData.Molecule) {
            self.molecule = molecule
        }

        func configure(view: SCNView, with mol: LigandData.Molecule, style: GeometryStyle) {
            scnView = view
            currentStyle = style
            let scene = view.scene ?? SCNScene()
            scene.rootNode.childNodes.forEach { $0.removeFromParentNode() }
            root.childNodes.forEach { $0.removeFromParentNode() }
            scene.rootNode.addChildNode(root)
            addLighting(to: scene)
            buildGeometry(for: mol, style: style)
            fitCamera(resetController: true)
        }

        func rebuild(style: GeometryStyle) {
            guard let view = scnView else { return }
            currentStyle = style
            root.childNodes.forEach { $0.removeFromParentNode() }
            buildGeometry(for: molecule, style: style)
            fitCamera(resetController: false)
            view.setNeedsDisplay()
        }

        func makeCameraNode() -> SCNNode {
            let cam = SCNCamera()
            cam.fieldOfView = 55
            cam.usesOrthographicProjection = false
            cam.zNear = 0.01
            cam.zFar = 1000
            let node = SCNNode()
            node.camera = cam
            node.position = SCNVector3(0, 0, 8)
            return node
        }

        private func addLighting(to scene: SCNScene) {
            let amb = SCNLight()
            amb.type = .ambient
            amb.intensity = 350
            let ambNode = SCNNode()
            ambNode.light = amb
            scene.rootNode.addChildNode(ambNode)

            let key = SCNLight()
            key.type = .directional
            key.intensity = 900
            let keyNode = SCNNode()
            keyNode.light = key
            keyNode.eulerAngles = SCNVector3(-Float.pi/4, Float.pi/4, 0)
            scene.rootNode.addChildNode(keyNode)

            let fill = SCNLight()
            fill.type = .directional
            fill.intensity = 550
            let fillNode = SCNNode()
            fillNode.light = fill
            fillNode.eulerAngles = SCNVector3(Float.pi/6, -Float.pi/3, 0)
            scene.rootNode.addChildNode(fillNode)
        }

        private func buildGeometry(for mol: LigandData.Molecule, style: GeometryStyle) {
            var atomNodes: [SCNNode] = []
            atomNodes.reserveCapacity(mol.atoms.count)

            let cfg = GeometryConfig(
                atomBaseRadius: atomRadius,
                bondBaseRadius: bondRadius,
                style: style,
                materialForSymbol: { [weak self] sym in self?.material(for: sym) ?? SCNMaterial() },
                scaleForSymbol: { sym in PeriodicTable.shared.scale(for: sym) ?? 1.0 },
                bondMaterial: bondMaterial
            )

            for (i, a) in mol.atoms.enumerated() {
                let node = GeometryFactory.makeAtomNode(atom: a, index: i, cfg: cfg)
                root.addChildNode(node)
                atomNodes.append(node)
            }

            for b in mol.bonds {
                let i1 = max(0, min(mol.atoms.count - 1, b.a1 - 1))
                let i2 = max(0, min(mol.atoms.count - 1, b.a2 - 1))
                guard i1 != i2 else { continue }
                let n1 = atomNodes[i1].position
                let n2 = atomNodes[i2].position
                let aScale = PeriodicTable.shared.scale(for: mol.atoms[i1].symbol) ?? 1.0
                let bScale = PeriodicTable.shared.scale(for: mol.atoms[i2].symbol) ?? 1.0
                let aR = atomRadius * aScale
                let bR = atomRadius * bScale
                let nodes = GeometryFactory.makeBondNodes(order: b.order, from: n1, to: n2, aRadius: aR, bRadius: bR, cfg: cfg)
                nodes.forEach { root.addChildNode($0) }
            }
        }

        private func material(for symbol: String) -> SCNMaterial {
            let key = symbol.uppercased()
            if let m = materialCache[key] { return m }
            let color = PeriodicTable.shared.color(for: key)
            let m = SCNMaterial()
            m.diffuse.contents = color
            m.metalness.contents = 0.05
            m.roughness.contents = 0.35
            m.lightingModel = .physicallyBased
            materialCache[key] = m
            return m
        }

        private func fitCamera(resetController: Bool) {
            guard let view = scnView, let camNode = view.pointOfView else { return }
            let (minV, maxV) = root.boundingBox
            let center = (minV + maxV) * 0.5
            let size = max(maxV.x - minV.x, max(maxV.y - minV.y, maxV.z - minV.z))
            let distance = Double(size) * 2.8 + 2.0
            camNode.position = SCNVector3(center.x, center.y, center.z + Float(distance))
            camNode.eulerAngles = SCNVector3Zero
            let constraint = SCNLookAtConstraint(target: root)
            constraint.isGimbalLockEnabled = true
            camNode.constraints = [constraint]
            if resetController {
                let ctrl = view.defaultCameraController
                ctrl.inertiaEnabled = true
                ctrl.interactionMode = .orbitTurntable
                ctrl.target = root.presentation.worldPosition
                ctrl.maximumVerticalAngle = 89
                ctrl.minimumVerticalAngle = -89
            }
        }

        func safeSnapshot() -> UIImage? {
            guard let v = scnView else { return nil }
            SCNTransaction.flush()
            return v.snapshot()
        }

        @objc func resetCamera() {
            fitCamera(resetController: true)
            updateSelectionBinding?(nil)
        }

        @objc func handleTap(_ gr: UITapGestureRecognizer) {
            guard let view = scnView else { return }
            let p = gr.location(in: view)
            let results = view.hitTest(p, options: [SCNHitTestOption.searchMode: SCNHitTestSearchMode.all.rawValue])
            if let atomNode = results.first(where: { $0.node.name?.hasPrefix("atom_") == true })?.node,
               let idStr = atomNode.name?.split(separator: "_").last,
               let idx = Int(idStr) {
                updateSelectionBinding?(idx)
            } else {
                updateSelectionBinding?(nil)
            }
        }
    }
}

extension SCNVector3 {
    static func + (l: SCNVector3, r: SCNVector3) -> SCNVector3 { SCNVector3(l.x+r.x, l.y+r.y, l.z+r.z) }
    static func - (l: SCNVector3, r: SCNVector3) -> SCNVector3 { SCNVector3(l.x-r.x, l.y-r.y, l.z-r.z) }
    static prefix func - (v: SCNVector3) -> SCNVector3 { SCNVector3(-v.x, -v.y, -v.z) }
    static func * (v: SCNVector3, s: Float) -> SCNVector3 { SCNVector3(v.x*s, v.y*s, v.z*s) }
    func length() -> Float { sqrtf(x*x + y*y + z*z) }
    func cross(_ v: SCNVector3) -> SCNVector3 { SCNVector3(y*v.z - z*v.y, z*v.x - x*v.z, x*v.y - y*v.x) }
    func normalized() -> SCNVector3 { let l = max(length(), 1e-6); return SCNVector3(x/l, y/l, z/l) }
    func dot(_ v: SCNVector3) -> Float { x*v.x + y*v.y + z*v.z }
}
