import Foundation
import SwiftData

@Model
final class UserAccount {
    @Attribute(.unique) var username: String
    var salt: Data
    var passwordHash: Data
    var createdAt: Date
    var biometricsEnabled: Bool

    init(username: String, salt: Data, passwordHash: Data, createdAt: Date = .now, biometricsEnabled: Bool = false) {
        self.username = username
        self.salt = salt
        self.passwordHash = passwordHash
        self.createdAt = createdAt
        self.biometricsEnabled = biometricsEnabled
    }
}

struct Session: Equatable {
    let username: String
    let startedAt: Date
}
