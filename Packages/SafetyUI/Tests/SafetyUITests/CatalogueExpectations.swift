import Testing

@testable import SafetyUI

/// Records an issue when `key` has no String Catalog entry: an unresolved key renders
/// as the key itself, which a person would then read.
func expectCatalogueEntry(_ key: String, sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(Strings.localized(String.LocalizationValue(key)) != key, "Missing catalogue entry: \(key)", sourceLocation: sourceLocation)
}
