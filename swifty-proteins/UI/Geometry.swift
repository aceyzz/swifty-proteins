import SceneKit
import UIKit

/*
	Geometrie sert maintenant a generer les differents format de rendus
	(ball&stick, wireframe, cpk) pour les bonus
*/
enum GeometryStyle: String, CaseIterable, Identifiable {
    case ballAndStick
    case wireframe
    case cpk
    var id: String { rawValue }
    var title: String {
        switch self {
        case .ballAndStick: return "Ball & Stick"
        case .wireframe: return "Wireframe"
        case .cpk: return "Space-filling (CPK)"
        }
    }
}

struct GeometryConfig {
    let atomBaseRadius: CGFloat
    let bondBaseRadius: CGFloat
    let style: GeometryStyle
    let materialForSymbol: (String) -> SCNMaterial
    let scaleForSymbol: (String) -> CGFloat
    let vdwRadiusForSymbol: (String) -> CGFloat
    let bondMaterial: SCNMaterial
}

protocol GeometryBuilder {
    func buildNodes(for mol: LigandData.Molecule, cfg: GeometryConfig) -> [SCNNode]
}

enum GeometryFactory {
    static func builder(for style: GeometryStyle) -> GeometryBuilder {
        switch style {
        case .ballAndStick: return BallStickBuilder()
        case .wireframe: return WireframeBuilder()
        case .cpk: return CPKBuilder()
        }
    }
}

struct BallStickBuilder: GeometryBuilder {
    func buildNodes(for mol: LigandData.Molecule, cfg: GeometryConfig) -> [SCNNode] {
        var nodes: [SCNNode] = []
        var atomNodes: [SCNNode] = []
        atomNodes.reserveCapacity(mol.atoms.count)

        for (i, a) in mol.atoms.enumerated() {
            let scale = cfg.scaleForSymbol(a.symbol)
            let r = cfg.atomBaseRadius * scale
            let g = SCNSphere(radius: r)
            g.segmentCount = 48
            g.materials = [cfg.materialForSymbol(a.symbol)]
            let n = SCNNode(geometry: g)
            n.position = SCNVector3(a.x, a.y, a.z)
            n.name = "atom_\(i)"
            atomNodes.append(n)
            nodes.append(n)
        }

        for b in mol.bonds {
            let i1 = max(0, min(mol.atoms.count - 1, b.a1 - 1))
            let i2 = max(0, min(mol.atoms.count - 1, b.a2 - 1))
            guard i1 != i2 else { continue }
            let a = atomNodes[i1].position
            let c = atomNodes[i2].position
            let u = (c - a).normalized()
            let ra = cfg.atomBaseRadius * cfg.scaleForSymbol(mol.atoms[i1].symbol)
            let rb = cfg.atomBaseRadius * cfg.scaleForSymbol(mol.atoms[i2].symbol)
            let aSurf = a + u * Float(ra)
            let bSurf = c - u * Float(rb)

            let main = cylinderNode(from: aSurf, to: bSurf, radius: cfg.bondBaseRadius)
            main.geometry?.materials = [cfg.bondMaterial]
            main.name = "bond"
            nodes.append(main)

            if b.order > 1 {
                let offsetAxis = perpendicularUnitVector(from: aSurf, to: bSurf) * Float(cfg.bondBaseRadius * 1.8)
                let count = b.order
                let start = -(count-1)/2
                for t in 0..<count {
                    if t == (count/2) { continue }
                    let o = offsetAxis * Float(t + start)
                    let extra = cylinderNode(from: aSurf + o, to: bSurf + o, radius: cfg.bondBaseRadius * 0.85)
                    extra.geometry?.materials = [cfg.bondMaterial]
                    extra.name = "bond"
                    nodes.append(extra)
                }
            }
        }
        return nodes
    }
}

struct WireframeBuilder: GeometryBuilder {
    func buildNodes(for mol: LigandData.Molecule, cfg: GeometryConfig) -> [SCNNode] {
        var nodes: [SCNNode] = []
        let positions: [SCNVector3] = mol.atoms.map { SCNVector3($0.x, $0.y, $0.z) }

        for b in mol.bonds {
            let i1 = max(0, min(positions.count - 1, b.a1 - 1))
            let i2 = max(0, min(positions.count - 1, b.a2 - 1))
            guard i1 != i2 else { continue }
            let a = positions[i1]
            let c = positions[i2]

            let main = cylinderNode(from: a, to: c, radius: cfg.bondBaseRadius * 0.5)
            main.geometry?.materials = [cfg.bondMaterial]
            main.name = "bond"
            nodes.append(main)

            if b.order > 1 {
                let offsetAxis = perpendicularUnitVector(from: a, to: c) * Float(cfg.bondBaseRadius)
                let count = b.order
                let start = -(count-1)/2
                for t in 0..<count {
                    if t == (count/2) { continue }
                    let o = offsetAxis * Float(t + start)
                    let extra = cylinderNode(from: a + o, to: c + o, radius: cfg.bondBaseRadius * 0.45)
                    extra.geometry?.materials = [cfg.bondMaterial]
                    extra.name = "bond"
                    nodes.append(extra)
                }
            }
        }
        return nodes
    }
}

struct CPKBuilder: GeometryBuilder {
    func buildNodes(for mol: LigandData.Molecule, cfg: GeometryConfig) -> [SCNNode] {
        var nodes: [SCNNode] = []
        for (i, a) in mol.atoms.enumerated() {
            let r = cfg.vdwRadiusForSymbol(a.symbol)
            let g = SCNSphere(radius: r)
            g.segmentCount = 48
            g.materials = [cfg.materialForSymbol(a.symbol)]
            let n = SCNNode(geometry: g)
            n.position = SCNVector3(a.x, a.y, a.z)
            n.name = "atom_\(i)"
            nodes.append(n)
        }
        return nodes
    }
}

private func cylinderNode(from: SCNVector3, to: SCNVector3, radius: CGFloat) -> SCNNode {
    let dir = to - from
    let h = CGFloat(dir.length())
    let g = SCNCylinder(radius: radius, height: h)
    let n = SCNNode(geometry: g)
    n.position = (from + to) * 0.5
    orient(node: n, along: dir)
    return n
}

private func orient(node: SCNNode, along dir: SCNVector3) {
    let yAxis = SCNVector3(0, 1, 0)
    let axis = yAxis.cross(dir).normalized()
    let dotv = max(min(yAxis.normalized().dot(dir.normalized()), 1.0), -1.0)
    let angle = acos(dotv)
    if !angle.isNaN, angle != 0 {
        node.rotation = SCNVector4(axis.x, axis.y, axis.z, angle)
    }
}

private func perpendicularUnitVector(from a: SCNVector3, to b: SCNVector3) -> SCNVector3 {
    let v = (b - a).normalized()
    let ref = abs(v.x) < 0.9 ? SCNVector3(1, 0, 0) : SCNVector3(0, 1, 0)
    return v.cross(ref).normalized()
}
