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
        // Checked before presenting, not after: some out-of-process controllers
        // delay setting `presentingViewController` until their own presentation
        // animation completes, so a check made right after `present` cannot tell
        // a refused presentation from a normal, still-animating one. See
        // `Presenter.presentable()`.
        guard let presenter = await Presenter.presentable() else { return .failed }

        return await withCheckedContinuation { continuation in
            let controller = MFMessageComposeViewController()
            let delegate = ComposeDelegate(continuation)
            controller.recipients = recipients.map(\.dialable)
            controller.body = body
            controller.messageComposeDelegate = delegate
            presenter.present(controller, animated: true)
            // Set only once `present` has returned: reading
            // `controller.presentationController` beforehand can create it with
            // the wrong presentation style.
            controller.presentationController?.delegate = delegate
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
    /// finish or a swipe-down dismissal.
    private func finish(_ outcome: MessageOutcome) {
        continuation?.resume(returning: outcome)
        continuation = nil
        keepAlive = nil
    }
}
