import MessageUI
import SafetyDomain
import SafetyServices

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
            presenter.present(controller, animated: true)
        }
    }
}

/// Reports what the person did, once. Keeps itself alive until then, because the
/// composer holds its delegate weakly.
private final class ComposeDelegate: NSObject, MFMessageComposeViewControllerDelegate {

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
        continuation?.resume(returning: outcome)
        continuation = nil
        keepAlive = nil
    }
}
