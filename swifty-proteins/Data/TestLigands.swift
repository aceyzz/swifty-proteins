import Foundation

struct SDFAtom: Hashable {
	let x: Double
	let y: Double
	let z: Double
	let symbol: String
	let charge: Int
}

struct SDFBond: Hashable {
	let a1: Int
	let a2: Int
	let order: Int
}

struct SDFMolecule: Hashable {
	let title: String
	let program: String
	let comment: String
	let atoms: [SDFAtom]
	let bonds: [SDFBond]
	let properties: [String: String]
}

struct SDFFile {
	let id: String
	let molecules: [SDFMolecule]
}

enum SDFParseError: Error {
	case empty
	case invalidCountsLine
	case invalidAtomLine(Int)
	case invalidBondLine(Int)
	case missingEnd
}

enum SDFParser {
	static func parse(_ text: String, id: String) throws -> SDFFile {
		let rawBlocks = text.components(separatedBy: "$$$$")
		let blocks = rawBlocks
			.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
			.filter { !$0.isEmpty }

		guard !blocks.isEmpty else { throw SDFParseError.empty }

		var mols: [SDFMolecule] = []
		mols.reserveCapacity(blocks.count)

		for block in blocks {
			mols.append(try parseSingleMol(block))
		}

		return SDFFile(id: id, molecules: mols)
	}

	private static func parseSingleMol(_ s: String) throws -> SDFMolecule {
		var lines = s.components(separatedBy: .newlines).map { $0.replacingOccurrences(of: "\r", with: "") }
		while lines.last?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
			lines.removeLast()
		}
		guard lines.count >= 4 else { throw SDFParseError.invalidCountsLine }

		let title = lines.removeFirst()
		let program = lines.removeFirst()
		let comment = lines.removeFirst()

		let counts = lines.removeFirst()
		guard let (natoms, nbonds) = parseCountsLine(counts) else {
			throw SDFParseError.invalidCountsLine
		}

		guard lines.count >= natoms else { throw SDFParseError.invalidAtomLine(lines.count) }
		var atoms: [SDFAtom] = []
		atoms.reserveCapacity(natoms)
		for i in 0..<natoms {
			guard let a = parseAtomLine(lines[i]) else { throw SDFParseError.invalidAtomLine(i + 1) }
			atoms.append(a)
		}

		guard lines.count >= natoms + nbonds else { throw SDFParseError.invalidBondLine(lines.count - natoms) }
		var bonds: [SDFBond] = []
		bonds.reserveCapacity(nbonds)
		for j in 0..<nbonds {
			guard let b = parseBondLine(lines[natoms + j]) else { throw SDFParseError.invalidBondLine(j + 1) }
			bonds.append(b)
		}

		var idx = natoms + nbonds
		var sawMEnd = false
		while idx < lines.count {
			let line = lines[idx].trimmingCharacters(in: .whitespaces)
			if line.hasPrefix("M  END") { sawMEnd = true; idx += 1; break }
			idx += 1
		}
		guard sawMEnd else { throw SDFParseError.missingEnd }

		var props: [String: String] = [:]
		while idx < lines.count {
			let raw = lines[idx]
			let line = raw.trimmingCharacters(in: .whitespaces)
			if line.hasPrefix(">") {
				if let name = extractPropertyName(line) {
					idx += 1
					var values: [String] = []
					while idx < lines.count {
						let v = lines[idx]
						if v.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { break }
						if v.trimmingCharacters(in: .whitespaces).hasPrefix(">") { break }
						values.append(v)
						idx += 1
					}
					props[name] = values.joined(separator: "\n")
				} else {
					idx += 1
				}
			} else {
				idx += 1
			}
		}

		return SDFMolecule(title: title, program: program, comment: comment, atoms: atoms, bonds: bonds, properties: props)
	}

	private static func parseCountsLine(_ s: String) -> (Int, Int)? {
		let trimmed = s.trimmingCharacters(in: .whitespaces)
		guard !trimmed.isEmpty else { return nil }
		let parts = trimmed.split { $0 == " " || $0 == "\t" }.map(String.init)
		guard parts.count >= 2, let a = Int(parts[0]), let b = Int(parts[1]) else { return nil }
		return (a, b)
	}

	private static func parseAtomLine(_ s: String) -> SDFAtom? {
		let p = s.split { $0 == " " || $0 == "\t" }.map(String.init)
		guard p.count >= 4 else { return nil }
		guard let x = Double(p[0]), let y = Double(p[1]), let z = Double(p[2]) else { return nil }
		let sym = p[3]
		var charge = 0
		if p.count >= 7, let code = Int(p[6]) {
			switch code {
			case 1: charge = 3
			case 2: charge = 2
			case 3: charge = 1
			case 5: charge = -1
			case 6: charge = -2
			case 7: charge = -3
			default: charge = 0
			}
		}
		return SDFAtom(x: x, y: y, z: z, symbol: sym, charge: charge)
	}

	private static func parseBondLine(_ s: String) -> SDFBond? {
		let p = s.split { $0 == " " || $0 == "\t" }.map(String.init)
		guard p.count >= 3, let a1 = Int(p[0]), let a2 = Int(p[1]), let order = Int(p[2]) else { return nil }
		return SDFBond(a1: a1, a2: a2, order: order)
	}

	private static func extractPropertyName(_ line: String) -> String? {
		guard let start = line.firstIndex(of: "<"), let end = line.firstIndexAfter(start, of: ">") else { return nil }
		return String(line[line.index(after: start)..<end])
	}
}

private extension String {
	func firstIndexAfter(_ i: Index, of ch: Character) -> Index? {
		var j = index(after: i)
		while j < endIndex {
			if self[j] == ch { return j }
			j = index(after: j)
		}
		return nil
	}
}

enum SDFFetchError: Error, LocalizedError {
	case notFound
	case network(String)
	case invalidData
	case parse(Error)
	case cacheMiss

	var errorDescription: String? {
		switch self {
		case .notFound: return "Fichier SDF introuvable (404)"
		case .network(let m): return "Erreur réseau: \(m)"
		case .invalidData: return "Données SDF invalides"
		case .parse(let e): return "Erreur de parsing: \(e)"
		case .cacheMiss: return "Aucune donnée en cache"
		}
	}
}

protocol SDFRepositing {
	func fetchLigand(id: String) async throws -> SDFFile
}

final class SDFRepository: SDFRepositing {
	private let session: URLSession
	private let base = "https://files.rcsb.org/ligands/download"
	private let fm = FileManager.default

	init(session: URLSession = .shared) {
		self.session = session
	}

	func fetchLigand(id: String) async throws -> SDFFile {
		let url = URL(string: "\(base)/\(id)_ideal.sdf")!
		do {
			let (data, resp) = try await session.data(from: url)
			if let http = resp as? HTTPURLResponse, http.statusCode == 404 { throw SDFFetchError.notFound }
			guard (resp as? HTTPURLResponse)?.statusCode ?? 200 < 300 else {
				throw SDFFetchError.network("HTTP \((resp as? HTTPURLResponse)?.statusCode ?? -1)")
			}
			let text = String(data: data, encoding: .utf8)
				?? String(data: data, encoding: .ascii)
				?? String(data: data, encoding: .isoLatin1)
			guard let text else { throw SDFFetchError.invalidData }

			let parsed: SDFFile
			do {
				parsed = try SDFParser.parse(text, id: id)
			} catch {
				throw SDFFetchError.parse(error)
			}
			try cacheSave(text: text, id: id)
			return parsed
		} catch let e as SDFFetchError {
			if let cached = try? cacheLoad(id: id) {
				do { return try SDFParser.parse(cached, id: id) }
				catch { throw SDFFetchError.parse(error) }
			}
			throw e
		} catch {
			if let cached = try? cacheLoad(id: id) {
				do { return try SDFParser.parse(cached, id: id) }
				catch { throw SDFFetchError.parse(error) }
			}
			throw SDFFetchError.network(error.localizedDescription)
		}
	}

	private func cacheDir() throws -> URL {
		let base = try fm.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
		let dir = base.appendingPathComponent("sdf", isDirectory: true)
		if !fm.fileExists(atPath: dir.path) {
			try fm.createDirectory(at: dir, withIntermediateDirectories: true)
		}
		return dir
	}

	private func cachePath(id: String) throws -> URL {
		try cacheDir().appendingPathComponent("\(id.uppercased()).sdf")
	}

	private func cacheSave(text: String, id: String) throws {
		let url = try cachePath(id: id)
		try text.write(to: url, atomically: true, encoding: .utf8)
	}

	private func cacheLoad(id: String) throws -> String {
		let url = try cachePath(id: id)
		guard fm.fileExists(atPath: url.path) else { throw SDFFetchError.cacheMiss }
		return try String(contentsOf: url, encoding: .utf8)
	}
}
