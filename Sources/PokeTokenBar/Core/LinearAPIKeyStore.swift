import Foundation

/// Linear personal API key — Application Support plaintext JSON (0600).
///
/// Same storage rule as `SessionKeyStore`: do **not** put this in the app Keychain
/// (resign ACL prompts; see defect log). Settings copy explains plaintext + revoke path.
struct LinearAPIKeyStore: Sendable {
    let fileURL: URL

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultURL()
    }

    private static func defaultURL() -> URL {
        AppStatePaths.directory().appendingPathComponent("linear-api-key.json")
    }

    struct Credential: Codable, Sendable, Equatable {
        var key: String
    }

    func load() -> Credential? {
        guard let data = try? Data(contentsOf: fileURL),
              let credential = try? JSONDecoder().decode(Credential.self, from: data),
              !credential.key.isEmpty
        else { return nil }
        return credential
    }

    func save(_ credential: Credential) throws {
        let data = try JSONEncoder().encode(credential)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: fileURL)
        FileManager.default.createFile(
            atPath: fileURL.path, contents: nil,
            attributes: [.posixPermissions: NSNumber(value: Int16(0o600))])
        try data.write(to: fileURL, options: .atomic)
        try? FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: Int16(0o600))], ofItemAtPath: fileURL.path)
    }

    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// Trim paste noise; Linear keys are `lin_api_…`.
    static func normalize(_ raw: String) throws -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("lin_api_"),
              trimmed.count >= 20,
              trimmed.count <= 512,
              !trimmed.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
        else { throw LinearAPIError.malformedKey }
        return trimmed
    }
}

enum LinearAPIError: Error, Equatable {
    case malformedKey
    case unauthorized
    case httpStatus(Int)
    case decoding
    case transport
}
