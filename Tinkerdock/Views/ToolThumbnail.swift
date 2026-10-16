import SwiftUI

struct ToolThumbnail: View {
    let tool: Tool
    @Environment(ThumbnailStore.self) private var thumbnails

    var body: some View {
        Color.clear
            .aspectRatio(4 / 3, contentMode: .fit)
            .overlay { content }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .task(id: tool.id) { thumbnails.ensure(tool) }
    }

    @ViewBuilder
    private var content: some View {
        if let image = thumbnails.images[tool.id] {
            if tool.kind == .app {
                placeholder.overlay {
                    Image(nsImage: image).resizable().scaledToFit().padding(20)
                }
            } else {
                Image(nsImage: image).resizable().scaledToFill()
            }
        } else {
            placeholder.overlay {
                Image(systemName: tool.kind.symbol)
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
    }

    private var placeholder: some View {
        let hue = Double(tool.id.uuid.0) / 255
        return LinearGradient(
            colors: [Color(hue: hue, saturation: 0.55, brightness: 0.7), Color(hue: (hue + 0.12).truncatingRemainder(dividingBy: 1), saturation: 0.6, brightness: 0.5)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
