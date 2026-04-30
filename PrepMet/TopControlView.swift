import SwiftUI

struct TopControlView: View {
    enum Kind {
        case text(String)
        case icon(String)
    }

    private static let controlHeight: CGFloat = 38
    private static let iconDiameter: CGFloat = 38
    private static let textHorizontalPadding: CGFloat = 14
    private static let iconSize: CGFloat = 17
    private static let shadowColor = Color.black.opacity(0.03)

    let kind: Kind

    var body: some View {
        switch kind {
        case .text(let title):
            surface(in: Capsule()) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .padding(.horizontal, Self.textHorizontalPadding)
                    .frame(height: Self.controlHeight)
            }

        case .icon(let systemName):
            surface(in: Circle()) {
                Image(systemName: systemName)
                    .font(.system(size: Self.iconSize, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: Self.iconDiameter, height: Self.iconDiameter)
            }
        }
    }

    private func surface<S: Shape, Content: View>(
        in shape: S,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .background(Color(.systemBackground), in: shape)
            .shadow(color: Self.shadowColor, radius: 2, y: 1)
    }
}
