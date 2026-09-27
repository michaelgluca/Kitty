import Foundation

/// How a search query is compared with the pack's text: deterministic, offline, and the
/// same on every phone.
public enum SearchText {

    /// Fixed, never the device's. The same query must find the same help on every phone
    /// and in every test run, and a phone set to Turkish must not fold "I" to a dotless
    /// "ı" and miss "STALKING". The pack is written in British English.
    public static let locale = Locale(identifier: "en_GB")

    /// Removed on both sides before comparing, so "women's" typed with iOS smart
    /// punctuation finds "Women's Aid", the pack's own curly apostrophes are found with a
    /// straight one, and "womens" finds both.
    static let apostrophes: Set<Character> = ["'", "\u{2018}", "\u{2019}", "\u{02BC}"]

    /// Case, diacritics and full-width forms folded; apostrophes removed.
    public static func normalise(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: locale)
            .filter { !apostrophes.contains($0) }
    }

    /// The words to search for: normalised, split on whitespace, with the punctuation
    /// around each word trimmed (curly quotes like "\u{201C}stalking\u{201D}," become "stalking").
    /// Empty when nothing searchable was typed, which is then no search at all rather than a search for nothing.
    public static func words(in query: String) -> [String] {
        normalise(query)
            .split(whereSeparator: { $0.isWhitespace })
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
    }

    /// Whether every word appears, as part of any word, in one of the fields. No words
    /// matches everything. Fields are joined with a line break, so one word can never
    /// match across two fields.
    public static func contains(_ words: [String], in fields: [String?]) -> Bool {
        guard !words.isEmpty else { return true }
        let haystack = fields.compactMap { $0 }.map(normalise).joined(separator: "\n")
        return words.allSatisfy { haystack.contains($0) }
    }
}
