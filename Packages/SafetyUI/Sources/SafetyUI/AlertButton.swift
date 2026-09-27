import SafetyDomain
import SwiftUI

/// The primary safety control.
///
/// Three things are deliberate and should not be "tidied up" later:
///
/// 1. **It is opaque, not glass.** Liquid Glass is mandatory for iOS 27 SDK builds
///    and standard components adopt it automatically, but a translucent primary
///    control over a map or a photograph is exactly where legibility fails. A
///    critical action must not depend on what happens to be behind it.
/// 2. **It has no fixed frame.** It grows with Dynamic Type all the way to AX5. The
///    2023 build used `width: 400`, which is wider than an iPhone SE.
/// 3. **It never relies on colour alone.** Red plus an icon plus a text label, so it
///    still reads under Differentiate Without Colour and for colour-blind users.
public struct PrimaryAlertButton: View {

    private let action: () -> Void
    @Environment(\.accessibilityPreferences) private var a11y
    @State private var isPressed = false

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Design.Space.base) {
                Image(systemName: "exclamationmark.bubble.fill")
                    .imageScale(.large)
                    .accessibilityHidden(true)
                Text("alert.button.title", bundle: .module)
                    .font(.title2.weight(.semibold))
                    // No lineLimit and no minimumScaleFactor: at AX5 this wraps to
                    // several lines and the button grows. Shrinking the text of the
                    // one control that matters would be the wrong trade.
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: Design.criticalTapTarget)
            .padding(.vertical, Design.Space.base)
            .padding(.horizontal, Design.Space.loose)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: Design.Radius.control, style: .continuous)
                    .fill(isPressed ? Color.alertFillPressed : Color.alertFill)
            )
            .overlay(
                // Increase Contrast wants a hard edge, not a tonal difference.
                RoundedRectangle(cornerRadius: Design.Radius.control, style: .continuous)
                    .strokeBorder(.white.opacity(a11y.increaseContrast ? 0.9 : 0), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: Design.Radius.control, style: .continuous))
        .accessibilityLabel(Text("alert.button.title", bundle: .module))
        .accessibilityHint(Text("alert.button.accessibilityHint", bundle: .module))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("alert.button")
        .onLongPressGesture(minimumDuration: 0, pressing: { pressing in
            // No animation under Reduce Motion; the state change still happens, so
            // the press is still visible.
            if a11y.reduceMotion {
                isPressed = pressing
            } else {
                withAnimation(.easeOut(duration: 0.12)) { isPressed = pressing }
            }
        }, perform: {})
    }
}

/// The standing statement that this app is not an emergency service.
///
/// Persistent rather than dismissible, and placed with the alert control rather than
/// buried in Settings. Apple does not mandate this wording — there is no such
/// guideline — but it is the cheapest defence against a reviewer reading the app as
/// an emergency service under 5.1.5, and it is honest.
public struct SafetyDisclaimer: View {
    @Environment(\.regionStance) private var region

    public init() {}

    /// Region-aware because this line is a bare instruction with no surrounding
    /// context. Telling someone in the United States to "call 999" would be wrong at
    /// exactly the moment it matters; 999 does not work there.
    static func key(for region: RegionStance) -> LocalizedStringKey {
        region.isUnitedKingdom ? "disclaimer.persistent" : "disclaimer.persistent.elsewhere"
    }

    public var body: some View {
        Text(Self.key(for: region), bundle: .module)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .accessibilityAddTraits(.isStaticText)
    }
}
