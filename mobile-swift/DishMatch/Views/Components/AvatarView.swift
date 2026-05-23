import SwiftUI

struct AvatarView: View {
    let name: String
    let userId: UUID
    var size: CGFloat = 40

    private static let avatarColors: [Color] = [
        Color(hex: "#d97757"),
        Color(hex: "#5b8dee"),
        Color(hex: "#4caf50"),
        Color(hex: "#9c27b0"),
        Color(hex: "#ff9800")
    ]

    private var avatarColor: Color {
        let hash = abs(userId.hashValue)
        return AvatarView.avatarColors[hash % AvatarView.avatarColors.count]
    }

    private var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(avatarColor.opacity(0.2))
                .frame(width: size, height: size)
            Text(initials)
                .font(.system(size: size * 0.36, weight: .semibold))
                .foregroundColor(avatarColor)
        }
    }
}
