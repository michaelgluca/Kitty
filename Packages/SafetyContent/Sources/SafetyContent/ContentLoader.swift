import Foundation

public enum ContentLoader {
    public enum Failure: Error, Equatable {
        case missingResource
        case malformed(String)
    }

    /// The bundled UK content pack.
    ///
    /// Loaded from a bundled resource rather than compiled-in literals so that the
    /// same file can be shipped to the Android port and validated by CI.
    public static func loadUK() throws -> ContentPack {
        guard let url = Bundle.module.url(forResource: "uk-content", withExtension: "json") else {
            throw Failure.missingResource
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(ContentPack.self, from: data)
        } catch let error as DecodingError {
            throw Failure.malformed(String(describing: error))
        }
    }

    /// Every outbound URL in the pack, for the CI allowlist check.
    public static func allURLs(in pack: ContentPack) -> [String] {
        (pack.services.map(\.url) + pack.emergencyRoutes.compactMap(\.learnMoreURL)).sorted()
    }
}
