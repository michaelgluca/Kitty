import MessageUI
import SafetyDomain
import SafetyServices
import UIKit

/// The system Messages sheet, pre-filled. The person always taps Send themselves:
/// iOS offers no way to send a message without that, and never will (ADR-0002).
struct SystemMessageComposer: MessageComposing {

    var canSendText: Bool { MFMessageComposeViewController.canSendText() }

    func compose(recipients: [PhoneNumber], body: String) async -> MessageOutcome {
        guard MFMessageComposeViewController.canSendText() else { return .unavailable }
        guard let presenter = Presenter.topViewController() else { return .failed }

        return await withCheckedContinuation { continuation in
            let controller = MFMessageComposeViewController()
            let delegate = ComposeDelegate(continuation)
            controller.recipients = recipients.map(\.dialable)
            controller.body = body
            controller.messageComposeDelegate = delegate
            controller.presentationController?.delegate = delegate
            presenter.present(controller, animated: true)
            // UIKit refuses a presentation silently — no delegate callback, only a
            // console warning — when the presenter is mid-transition or not in the
            // window hierarchy. It sets `presentingViewController` synchronously
            // when it accepts the request, so its absence right after `present`
            // means the sheet never appeared and the continuation must still
            // resolve, rather than hang the alert forever.
            if controller.presentingViewController == nil {
                delegate.finish(.failed)
            }
        }
    }
}

/// Reports what the person did, once. Keeps itself alive until then, because the
/// composer holds its delegate weakly.
private final class ComposeDelegate: NSObject, MFMessageComposeViewControllerDelegate, UIAdaptivePresentationControllerDelegate {

    private var continuation: CheckedContinuation<MessageOutcome, Never>?
    private var keepAlive: ComposeDelegate?

    init(_ continuation: CheckedContinuation<MessageOutcome, Never>) {
        self.continuation = continuation
        super.init()
        keepAlive = self
    }

    func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
        controller.dismiss(animated: true)
        let outcome: MessageOutcome = switch result {
        case .sent: .sent
        case .cancelled: .cancelled
        case .failed: .failed
        @unknown default: .failed
        }
        finish(outcome)
    }

    /// A swipe-down dismissal reports no `MessageComposeResult` at all.
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        finish(.cancelled)
    }

    /// Resumes the continuation exactly once, however the sheet ended — a normal
    /// finish, a swipe-down dismissal, or a presentation UIKit silently refused.
    func finish(_ outcome: MessageOutcome) {
        continuation?.resume(returning: outcome)
        continuation = nil
        keepAlive = nil
    }
}
