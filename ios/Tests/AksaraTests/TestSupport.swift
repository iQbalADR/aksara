import Foundation
@testable import Aksara

enum TestSupport {
    /// A throwaway directory unique per call — keeps each test's disk cache isolated.
    static func makeTempDir() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("AksaraTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func data(_ json: String) -> Data { Data(json.utf8) }
}

/// A custom parser for a non-i18next format: `{"items":[{"id":"a.b","text":"…"}]}`.
/// Demonstrates injecting a consumer-defined JSON model via `LocalizationConfig.parser`.
struct ListParser: TranslationParser {
    struct Doc: Decodable {
        struct Item: Decodable { let id: String; let text: String }
        let items: [Item]
    }

    func parse(_ data: Data, language: String) throws -> [String: String] {
        let doc = try JSONDecoder().decode(Doc.self, from: data)
        return Dictionary(uniqueKeysWithValues: doc.items.map { ($0.id, $0.text) })
    }
}
