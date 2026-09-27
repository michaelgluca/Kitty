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
}
