import AppKit
import SwiftUI

/// Vertical list of windows, one row each: icon · app name · title.
/// Selected row gets an accent-colored rounded highlight; auto-scrolls
/// to keep selection visible.
struct SwitcherView: View {
    @ObservedObject var model: SwitcherViewModel

    static let rowHeight: CGFloat = 36
    static let maxVisibleRows = 14
    static let panelWidth: CGFloat = 560

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 2) {
                    ForEach(Array(model.windows.enumerated()), id: \.element.id) { index, window in
                        SwitcherRow(
                            window: window,
                            isSelected: index == model.selectionIndex
                        )
                        .id(window.id)
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 6)
            }
            .frame(width: Self.panelWidth, height: panelHeight)
            .background(
                VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .onChange(of: model.selectionIndex) { _ in
                scrollToSelection(proxy)
            }
            .onAppear {
                scrollToSelection(proxy)
            }
        }
    }

    private var panelHeight: CGFloat {
        let rows = min(max(model.windows.count, 1), Self.maxVisibleRows)
        return CGFloat(rows) * (Self.rowHeight + 2) + 12
    }

    private func scrollToSelection(_ proxy: ScrollViewProxy) {
        guard model.windows.indices.contains(model.selectionIndex) else { return }
        let id = model.windows[model.selectionIndex].id
        proxy.scrollTo(id, anchor: .center)
    }
}

private struct SwitcherRow: View {
    let window: WindowInfo
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            iconView
                .frame(width: 24, height: 24)
            Text(window.appName)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .layoutPriority(1)
            Text(title)
                .font(.system(size: 13))
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundColor(.secondary)
                .opacity(window.isMinimized ? 0.55 : 1.0)
            Spacer(minLength: 0)
            if window.isMinimized {
                Image(systemName: "minus.rectangle")
                    .foregroundColor(.secondary)
                    .font(.system(size: 11))
            }
        }
        .padding(.horizontal, 10)
        .frame(height: SwitcherView.rowHeight)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.35) : Color.clear)
        )
        .contentShape(Rectangle())
    }

    private var title: String {
        window.title.isEmpty ? "(untitled)" : window.title
    }

    @ViewBuilder
    private var iconView: some View {
        if let icon = window.icon {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
        } else {
            RoundedRectangle(cornerRadius: 5).fill(Color.gray.opacity(0.3))
        }
    }
}

/// NSVisualEffectView bridge — SwiftUI's `.ultraThinMaterial` doesn't
/// reach behind the window the way HUD vibrancy does.
private struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blendingMode
    }
}
