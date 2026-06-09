import AppKit
import SwiftUI

/// Vertical list of windows, one row each: icon · app name · title.
/// Selected row gets an accent-colored highlight with white text;
/// auto-scrolls to keep selection visible.
struct SwitcherView: View {
    @ObservedObject var model: SwitcherViewModel

    static let rowHeight: CGFloat = 44
    static let outerCornerRadius: CGFloat = 18

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 1) {
                    ForEach(Array(model.windows.enumerated()), id: \.element.id) { index, window in
                        SwitcherRow(
                            window: window,
                            isSelected: index == model.selectionIndex
                        )
                        .id(window.id)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 8)
            }
            .frame(width: model.panelWidth, height: panelHeight)
            .background(
                VisualEffectBackground(material: .popover, blendingMode: .behindWindow)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Self.outerCornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Self.outerCornerRadius, style: .continuous))
            .onChange(of: model.selectionIndex) { _ in
                scrollToSelection(proxy)
            }
            .onAppear {
                scrollToSelection(proxy)
            }
        }
    }

    private var panelHeight: CGFloat {
        let rows = min(max(model.windows.count, 1), model.maxVisibleRows)
        return CGFloat(rows) * (Self.rowHeight + 1) + 16
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
        HStack(spacing: 12) {
            iconView
                .frame(width: 28, height: 28)
                .shadow(color: .black.opacity(0.15), radius: 0.5, y: 0.5)
            Text(window.appName)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundColor(primaryColor)
                .lineLimit(1)
                .layoutPriority(1)
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(secondaryColor)
                .lineLimit(1)
                .truncationMode(.middle)
                .opacity(window.isMinimized ? 0.6 : 1.0)
            Spacer(minLength: 0)
            if window.isMinimized {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(secondaryColor)
                    .font(.system(size: 12))
            }
        }
        .padding(.horizontal, 12)
        .frame(height: SwitcherView.rowHeight)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.85) : Color.clear)
        )
        .contentShape(Rectangle())
    }

    private var primaryColor: Color {
        isSelected ? .white : .primary
    }

    private var secondaryColor: Color {
        isSelected ? Color.white.opacity(0.85) : .secondary
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
            RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.3))
        }
    }
}

/// NSVisualEffectView bridge — SwiftUI's `.ultraThinMaterial` doesn't
/// reach behind the window the way native vibrancy does.
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
