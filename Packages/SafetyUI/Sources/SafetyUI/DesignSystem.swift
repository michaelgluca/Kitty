import SwiftUI

/// Layout and type decisions that have to hold under stress, one-handed, in the dark.
public enum Design {

    /// The HIG minimum comfortable hit target. Anything interactive clears this, and
    /// anything on the alert path clears `criticalTapTarget`.
    public static let minimumTapTarget: CGFloat = 44

    /// Primary safety actions are deliberately much larger than the minimum. Someone
    /// with shaking hands, in the dark, should not have to aim.
    public static let criticalTapTarget: CGFloat = 96

    public enum Space {
        public static let tight: CGFloat = 8
        public static let base: CGFloat = 16
        public static let loose: CGFloat = 24
        /// Side gutter. Never let content reach the bezel.
        public static let gutter: CGFloat = 20
    }

    public enum Radius {
        public static let control: CGFloat = 16
        public static let card: CGFloat = 20
    }
}

public extension ShapeStyle where Self == Color {
    /// The alert control's fill.
    ///
    /// Deliberately an opaque colour rather than a glass effect. Liquid Glass is
    /// mandatory for iOS 27 SDK builds and standard components adopt it
    /// automatically, but a translucent primary control over a map or a photo is
    /// exactly where legibility fails. A critical action must not depend on what
    /// happens to be behind it.
    static var alertFill: Color { Color(.sRGB, red: 0.72, green: 0.11, blue: 0.16, opacity: 1) }
    static var alertFillPressed: Color { Color(.sRGB, red: 0.58, green: 0.08, blue: 0.13, opacity: 1) }
}

/// Reads the accessibility settings that change how the UI must be drawn.
///
/// Grouped so no view forgets one: Reduce Transparency and Increase Contrast in
/// particular interact with Liquid Glass, and are easy to miss in review.
public struct AccessibilityPreferences: Sendable, Equatable {
    public var reduceMotion: Bool
    public var reduceTransparency: Bool
    public var increaseContrast: Bool
    public var boldText: Bool
    public var buttonShapes: Bool
    public var differentiateWithoutColor: Bool

    public init(
        reduceMotion: Bool = false,
        reduceTransparency: Bool = false,
        increaseContrast: Bool = false,
        boldText: Bool = false,
        buttonShapes: Bool = false,
        differentiateWithoutColor: Bool = false
    ) {
        self.reduceMotion = reduceMotion
        self.reduceTransparency = reduceTransparency
        self.increaseContrast = increaseContrast
        self.boldText = boldText
        self.buttonShapes = buttonShapes
        self.differentiateWithoutColor = differentiateWithoutColor
    }

    /// True when the system is asking us not to use translucency. Any glass surface
    /// must fall back to an opaque one.
    public var prefersOpaqueSurfaces: Bool { reduceTransparency || increaseContrast }
}

public extension EnvironmentValues {
    var accessibilityPreferences: AccessibilityPreferences {
        AccessibilityPreferences(
            reduceMotion: accessibilityReduceMotion,
            reduceTransparency: accessibilityReduceTransparency,
            increaseContrast: colorSchemeContrast == .increased,
            boldText: legibilityWeight == .bold,
            differentiateWithoutColor: accessibilityDifferentiateWithoutColor
        )
    }
}
