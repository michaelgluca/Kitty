import Observation
import SwiftUI

/// Whether Test Mode is on, for this session only.
///
/// Never saved. Off at every launch, and off whenever the app goes to the background.
/// Left on by accident, Test Mode would send a real alert to drama numbers and dial
/// a drama number instead of 999, so the moment someone leaves the app — the moment
/// it is most likely to be forgotten — it switches itself off.
@MainActor
@Observable
public final class TestModeSession {

    public var isOn = false

    public init() {}

    public func scenePhaseChanged(to phase: ScenePhase) {
        if phase == .background { isOn = false }
    }
}

/// Shown at the top of every screen that can call or text while Test Mode is on.
/// Opaque, loud, and one tap to turn off.
struct TestModeBanner: View {

    let session: TestModeSession

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Space.tight) {
            Label {
                Text("testMode.banner.title", bundle: .module).font(.headline)
            } icon: {
                Image(systemName: "testtube.2")
            }
            Text("testMode.banner.body", bundle: .module)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                session.isOn = false
            } label: {
                Text("testMode.banner.turnOff", bundle: .module)
                    .font(.body.weight(.semibold))
                    .frame(minHeight: Design.minimumTapTarget)
            }
            .buttonStyle(.borderedProminent)
            .tint(.black)
            .accessibilityIdentifier("testMode.turnOff")
        }
        .foregroundStyle(.black)
        .padding(Design.Space.base)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Design.Radius.card, style: .continuous).fill(Color.testModeFill)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("testMode.banner")
    }
}
