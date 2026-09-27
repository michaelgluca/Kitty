import UIKit

/// Finds the view controller to present system sheets from.
enum Presenter {

    /// The top-most view controller in the foreground window, or `nil` if there is
    /// none — in which case the caller reports failure rather than presenting nothing.
    static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        // A `.foregroundActive` scene is preferred, but a scene the system has
        // briefly made `.foregroundInactive` — a `tel:` confirmation, Notification
        // Centre, Control Centre — can still accept a presentation. Reporting
        // failure just because of that would refuse a sheet UIKit would in fact show.
        let scene = scenes.first { $0.activationState == .foregroundActive }
            ?? scenes.first { $0.activationState == .foregroundInactive }
        guard var top = scene?.keyWindow?.rootViewController else { return nil }
        // A presented controller already on its way out cannot itself present.
        // Stop one level up and let the caller present from there instead.
        while let presented = top.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }

    /// The view controller to present a system sheet from right now, or `nil` if
    /// none can currently accept one.
    ///
    /// `present(_:animated:)` fails silently — no delegate callback, only a
    /// console warning — when the target is mid-transition, already presenting,
    /// being presented itself, or being dismissed. Checking `presentingViewController`
    /// after calling `present` cannot tell the difference: some out-of-process
    /// controllers (`CNContactPickerViewController` among them) delay setting it
    /// until their own presentation animation completes, sometimes by several
    /// seconds, so that check fires on every normal presentation, not just a
    /// refused one. Checking first, here, is what actually distinguishes the two.
    ///
    /// A transition already running is given one chance to finish — refusing a
    /// presentation that would in fact succeed a moment later would be its own
    /// kind of silent failure — and then the state is re-read and checked once
    /// more before handing back a controller.
    static func presentable() async -> UIViewController? {
        guard var top = topViewController() else { return nil }
        if let coordinator = top.transitionCoordinator {
            await withCheckedContinuation { continuation in
                // `animate(alongsideTransition:completion:)` returns `false` when it
                // did not queue the animation, in which case the completion handler
                // never runs. The two resumes are mutually exclusive: `false` means
                // the completion will never fire, so resuming here cannot race it.
                // Without this, that case would leave the continuation — and the
                // alert — hanging forever.
                if !coordinator.animate(alongsideTransition: nil, completion: { _ in continuation.resume() }) {
                    continuation.resume()
                }
            }
            guard let refreshed = topViewController() else { return nil }
            top = refreshed
        }
        guard top.viewIfLoaded?.window != nil,
              top.presentedViewController == nil,
              !top.isBeingPresented,
              !top.isBeingDismissed,
              top.transitionCoordinator == nil
        else { return nil }
        return top
    }
}
