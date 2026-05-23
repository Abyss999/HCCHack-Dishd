import SwiftUI

struct ExpandedResultsView: View {
    let results: [SessionResult]
    let sessionCode: String
    var onDone: () -> Void

    private let primary = Color(red: 0.851, green: 0.467, blue: 0.341)
    private let medals = ["🥇", "🥈", "🥉"]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Results")
                    .font(.system(size: 22, weight: .black))
                    .foregroundColor(.white)
                Spacer()
                Button("Done") { onDone() }
                    .foregroundColor(primary)
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(Array(results.enumerated()), id: \.element.id) { idx, r in
                        HStack(spacing: 14) {
                            Text(medals[safe: idx] ?? "#\(idx + 1)")
                                .font(.system(size: 22))
                                .frame(width: 40)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(r.restaurant.name)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.white)
                                if let addr = r.restaurant.address {
                                    Text(addr)
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(Int(r.scorePct))%")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(primary)
                                Text("\(r.yesCount)/\(r.total)")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(14)
                        .background(Color(red: 0.102, green: 0.102, blue: 0.102))
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 24)
            }

            if results.isEmpty {
                Text("No results yet — everyone needs to swipe first!")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(40)
            }
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
