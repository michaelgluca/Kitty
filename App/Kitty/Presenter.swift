import UIKit

/// Finds the view controller to present system sheets from.
enum Presenter {

    /// The top-most view controller in the foreground window, or `nil` if there is
    /// none — in which case the caller reports failure rather than presenting nothing.
    static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        guard var top = scene?.keyWindow?.rootViewController else { return nil }
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}
