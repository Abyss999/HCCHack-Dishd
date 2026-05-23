import Messages
import SwiftUI
import UIKit

final class MessagesViewController: MSMessagesAppViewController {

    private let authHelper = MessageAuthHelper()
    private var currentHostingController: UIViewController?
    private var pendingSession: Session?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
    }

    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)
        presentView(for: conversation, mode: presentationStyle)
    }

    override func willTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        super.willTransition(to: presentationStyle)
        removeCurrentHostingController()
    }

    override func didTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        super.didTransition(to: presentationStyle)
        guard let conversation = activeConversation else { return }
        presentView(for: conversation, mode: presentationStyle)
    }

    // MARK: - Routing

    private func presentView(for conversation: MSConversation, mode: MSMessagesAppPresentationStyle) {
        let token = authHelper.loadToken()

        if let selected = conversation.selectedMessage,
           let info = SessionURLParser.parse(selected.url) {
            presentJoinFlow(info: info, token: token, conversation: conversation, mode: mode)
            return
        }

        guard let token else {
            host(CompactLoginView(onLoginSuccess: { [weak self] in
                guard let self, let conv = self.activeConversation else { return }
                self.presentView(for: conv, mode: self.presentationStyle)
            }))
            return
        }

        switch mode {
        case .compact:
            host(CompactSessionView(
                token: token,
                onSessionCreated: { [weak self] session in
                    self?.pendingSession = session
                    self?.requestPresentationStyle(.expanded)
                },
                onJoinSession: { [weak self] session in
                    self?.pendingSession = session
                    self?.requestPresentationStyle(.expanded)
                },
                onSendMessage: { [weak self] session in
                    guard let self, let conv = self.activeConversation else { return }
                    self.insertMessage(for: session, into: conv)
                }
            ))
        case .expanded:
            if let session = pendingSession {
                pendingSession = nil
                host(ExpandedSwipeView(
                    sessionId: session.id,
                    sessionCode: session.code,
                    token: token,
                    onSendUpdatedMessage: { [weak self] s in
                        guard let self, let conv = self.activeConversation else { return }
                        self.insertMessage(for: s, into: conv)
                    },
                    onDone: { [weak self] in self?.dismiss() }
                ))
            } else {
                requestPresentationStyle(.compact)
            }
        @unknown default:
            break
        }
    }

    private func presentJoinFlow(info: SessionInfo,
                                  token: String?,
                                  conversation: MSConversation,
                                  mode: MSMessagesAppPresentationStyle) {
        guard let token else {
            host(CompactLoginView(onLoginSuccess: { [weak self] in
                guard let self, let conv = self.activeConversation else { return }
                self.presentView(for: conv, mode: self.presentationStyle)
            }))
            return
        }

        if mode == .compact {
            requestPresentationStyle(.expanded)
        }

        host(ExpandedSwipeView(
            sessionId: info.sessionId,
            sessionCode: info.code,
            token: token,
            onSendUpdatedMessage: { [weak self] session in
                guard let self, let conv = self.activeConversation else { return }
                self.insertMessage(for: session, into: conv)
            },
            onDone: { [weak self] in self?.dismiss() }
        ))
    }

    // MARK: - Message insertion

    private func insertMessage(for session: Session, into conversation: MSConversation) {
        let message = MSMessageBuilder.build(session: session)
        conversation.insert(message) { error in
            if let error { print("[DishMatch] message insert error: \(error)") }
        }
    }

    // MARK: - Child VC hosting

    private func host<V: View>(_ swiftUIView: V) {
        removeCurrentHostingController()
        let themed = swiftUIView.environmentObject(ThemeStore())
        let host = UIHostingController(rootView: themed)
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.backgroundColor = .clear
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
        currentHostingController = host
    }

    private func removeCurrentHostingController() {
        currentHostingController?.willMove(toParent: nil)
        currentHostingController?.view.removeFromSuperview()
        currentHostingController?.removeFromParent()
        currentHostingController = nil
    }
}
