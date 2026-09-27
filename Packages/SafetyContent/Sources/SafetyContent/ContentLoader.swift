import Foundation
import SafetyDomain

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
            let pack = try JSONDecoder().decode(ContentPack.self, from: data)
            try pack.validate()
            return pack
        } catch let failure as Failure {
            throw failure
        } catch let error as DecodingError {
            throw Failure.malformed(String(describing: error))
        }
    }

    /// Every URL a user can be sent to, for the CI allowlist check.
    ///
    /// Sources are deliberately excluded: they are the pages an entry was verified
    /// against, recorded for reviewers, and are never shown to a user.
    public static func allURLs(in pack: ContentPack) -> [String] {
        Array(Set(
            pack.services.map(\.url)
                + pack.reporting(for: .unitedKingdom).map(\.url)
                + pack.emergencyRoutes.compactMap(\.learnMoreURL)
                + pack.guides.map(\.url)
        )).sorted()
    }
}
