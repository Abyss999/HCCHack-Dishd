import Messages
import UIKit

enum MSMessageBuilder {

    static func build(session: Session) -> MSMessage {
        let message = MSMessage(session: MSSession())

        let layout = MSMessageTemplateLayout()
        layout.caption = "DishMatch"
        layout.subcaption = "Tap to vote on restaurants"
        layout.trailingCaption = session.code
        layout.trailingSubcaption = "\(session.members.count) swiping"
        layout.image = makeBubbleImage(session: session)

        message.layout = layout
        message.url = SessionURLParser.encode(session: session)
        message.summaryText = "Invited you to a DishMatch session"

        return message
    }

    private static func makeBubbleImage(session: Session) -> UIImage {
        let size = CGSize(width: 400, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor(red: 0.851, green: 0.467, blue: 0.341, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            let cfg = UIImage.SymbolConfiguration(pointSize: 56, weight: .regular)
            if let icon = UIImage(systemName: "fork.knife.circle.fill", withConfiguration: cfg)?
                .withTintColor(.white, renderingMode: .alwaysOriginal) {
                icon.draw(in: CGRect(x: 20, y: 72, width: 80, height: 80))
            }

            let title: [NSAttributedString.Key: Any] = [
                .foregroundColor: UIColor.white,
                .font: UIFont.boldSystemFont(ofSize: 26)
            ]
            "DishMatch".draw(at: CGPoint(x: 118, y: 76), withAttributes: title)

            let sub: [NSAttributedString.Key: Any] = [
                .foregroundColor: UIColor.white.withAlphaComponent(0.8),
                .font: UIFont.systemFont(ofSize: 16)
            ]
            "Code: \(session.code)".draw(at: CGPoint(x: 118, y: 116), withAttributes: sub)
        }
    }
}
