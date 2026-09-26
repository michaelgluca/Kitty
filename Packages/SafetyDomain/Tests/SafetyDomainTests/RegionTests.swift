import Foundation
import Testing

@testable import SafetyDomain

@Suite("Region resolution")
struct RegionTests {

    @Test("A GB device region shows UK services")
    func deviceRegionGB() {
        #expect(RegionResolver.resolve(RegionSignals(deviceRegion: "GB")).isUnitedKingdom)
    }

    @Test("The storefront alone is enough, and its alpha-3 code is understood")
    func storefrontAlpha3() {
        // StoreKit reports the storefront as an alpha-3 code such as GBR, while the
        // device region is alpha-2. Comparing them naively would never match.
        #expect(RegionResolver.resolve(RegionSignals(storefrontCode: "GBR")).isUnitedKingdom)
    }

    @Test("Either signal saying GB is enough")
    func biasTowardsUK() {
        // A UK resident with their phone set to en_US is a real and common case.
        // Wrongly showing UK services abroad is harmless; wrongly hiding them at home
        // is not, so the resolver is deliberately biased.
        #expect(RegionResolver.resolve(RegionSignals(deviceRegion: "US", storefrontCode: "GBR")).isUnitedKingdom)
        #expect(RegionResolver.resolve(RegionSignals(deviceRegion: "GB", storefrontCode: "USA")).isUnitedKingdom)
    }

    @Test("Neither signal saying GB gives the non-UK stance, keeping the country code")
    func elsewhere() {
        #expect(RegionResolver.resolve(RegionSignals(deviceRegion: "FR", storefrontCode: "FRA"))
            == .elsewhere(countryCode: "FR"))
    }

    @Test("No signals at all is handled, and is not treated as the UK")
    func noSignals() {
        // Claiming the UK on no evidence would show 999 to someone who may be
        // anywhere. Showing the notice is the safe default.
        #expect(RegionResolver.resolve(RegionSignals()) == .elsewhere(countryCode: nil))
    }

    @Test("A user override beats both signals, in both directions")
    func overrideWins() {
        #expect(RegionResolver.resolve(
            RegionSignals(deviceRegion: "US", storefrontCode: "USA", userOverride: .unitedKingdom)
        ).isUnitedKingdom)

        // Someone who has left the UK must be able to say so and stop being told to
        // call 999.
        #expect(!RegionResolver.resolve(
            RegionSignals(deviceRegion: "GB", storefrontCode: "GBR", userOverride: .elsewhere(countryCode: "ES"))
        ).isUnitedKingdom)
    }

    @Test("Case and the non-ISO \"UK\" spelling are accepted")
    func normalisation() {
        #expect(RegionResolver.normalise("gb") == "GB")
        #expect(RegionResolver.normalise("gbr") == "GB")
        #expect(RegionResolver.normalise("UK") == "GB")
        #expect(RegionResolver.normalise("") == nil)
        #expect(RegionResolver.normalise(nil) == nil)
    }
}
