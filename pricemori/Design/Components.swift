import SwiftUI
import UIKit

@MainActor
private func endTextEditing() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

struct ScreenScaffold<Content: View, Footer: View, Trailing: View>: View {
    @Environment(\.locale) private var locale
    @Binding private var saveError: Bool
    @State private var isEditingText = false
    let title: String?
    let backLabel: String?
    let showsBackChevron: Bool
    let backAction: (() -> Void)?
    let trailing: Trailing
    let footer: Footer
    let content: Content
    let topPadding: CGFloat
    let scrollsContent: Bool

    init(
        saveError: Binding<Bool> = .constant(false),
        title: String? = nil,
        backLabel: String? = nil,
        showsBackChevron: Bool = true,
        backAction: (() -> Void)? = nil,
        topPadding: CGFloat = 16,
        scrollsContent: Bool = true,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() },
        @ViewBuilder footer: () -> Footer = { EmptyView() },
        @ViewBuilder content: () -> Content
    ) {
        _saveError = saveError
        self.title = title
        self.backLabel = backLabel
        self.showsBackChevron = showsBackChevron
        self.backAction = backAction
        self.trailing = trailing()
        self.footer = footer()
        self.content = content()
        self.topPadding = topPadding
        self.scrollsContent = scrollsContent
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(
                title: title,
                backLabel: backLabel,
                showsBackChevron: showsBackChevron,
                backAction: backAction,
                trailing: AnyView(trailing)
            )
            .fixedSize(horizontal: false, vertical: true)
            if scrollsContent {
                ScrollView {
                    content
                        .padding(.horizontal, 24)
                        .padding(.top, topPadding)
                        .padding(.bottom, 24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollDismissesKeyboard(.interactively)
                .scrollIndicators(.hidden)
                .frame(minHeight: 0, maxHeight: .infinity)
                .layoutPriority(-1)
            } else {
                content
            }

        }
        .onPreferenceChange(TextFieldFocusKey.self) { isEditingText = $0 }
        .modifier(ScreenFooter(footer: footer, isEditingText: isEditingText))
        .background(Theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .id(locale.identifier)
        .alert("Could not save changes", isPresented: $saveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your changes were not saved. Please try again.")
        }
    }
}

private struct TextFieldFocusKey: PreferenceKey {
    static let defaultValue = false

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

private struct ScreenFooter<Footer: View>: ViewModifier {
    let footer: Footer
    let isEditingText: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.safeAreaBar(edge: .bottom, spacing: 0) { actions }
        } else {
            content.safeAreaInset(edge: .bottom, spacing: 0) { actions }
        }
    }

    @ViewBuilder
    private var actions: some View {
        if !(footer is EmptyView) || isEditingText {
            VStack(spacing: 8) {
                if isEditingText {
                    HStack {
                        Spacer()
                        Button("Done") { endTextEditing() }
                            .font(AppFont.inter(16, .semibold))
                            .foregroundStyle(Theme.accent)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                            .accessibilityIdentifier("keyboard-done")
                            .buttonStyle(.plain)
                    }
                }
                footer
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity)
            .background(Theme.background)
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct ScreenHeader: View {
    let title: String?
    var backLabel: String? = nil
    var showsBackChevron: Bool = true
    var backAction: (() -> Void)? = nil
    var trailing: AnyView = AnyView(EmptyView())

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 0) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 6) {
                    controls
                    if let title {
                        Text(L10n.string(title))
                            .font(AppFont.inter(17, .semibold))
                            .foregroundStyle(Theme.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.bottom, 8)
                    }
                }
                .padding(.horizontal, 16)
            } else {
                ZStack {
                    if let title {
                        Text(L10n.string(title))
                            .font(AppFont.inter(17, .semibold))
                            .foregroundStyle(Theme.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    controls
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 58)
            }
            Theme.separator.frame(height: 1)
        }
        .background(Theme.background)
    }

    private var controls: some View {
        HStack(spacing: 8) {
            if backAction != nil || backLabel != nil {
                Button {
                    endTextEditing()
                    if let backAction { backAction() } else { dismiss() }
                } label: {
                    HStack(spacing: 6) {
                        if showsBackChevron {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        if let backLabel {
                            Text(L10n.string(backLabel))
                                .font(AppFont.inter(15, .medium))
                                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                    .foregroundStyle(Theme.primaryText)
                    .frame(width: 130, alignment: .leading)
                    .frame(minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
            trailing.frame(minWidth: 56, minHeight: 44, alignment: .trailing)
        }
    }
}

struct HeaderActionButton: View {
    let title: String
    var action: () -> Void

    var body: some View {
        Button {
            endTextEditing()
            action()
        } label: {
            Text(L10n.string(title))
                .font(AppFont.inter(15, .medium))
                .foregroundStyle(Theme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct PrimaryButton: View {
    let title: String
    var isEnabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button {
            endTextEditing()
            action()
        } label: {
            Text(L10n.string(title))
                .font(AppFont.inter(16, .semibold))
                .foregroundStyle(Theme.onAccent)
                .multilineTextAlignment(.center)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .opacity(isEnabled ? 1 : 0.45)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

struct SecondaryButton: View {
    let title: String
    var color: Color = Theme.secondaryText
    var action: () -> Void

    var body: some View {
        Button {
            endTextEditing()
            action()
        } label: {
            Text(L10n.string(title))
                .font(AppFont.inter(16, .semibold))
                .foregroundStyle(color)
                .multilineTextAlignment(.center)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button {
            endTextEditing()
            action()
        } label: {
            Text(L10n.string(title))
                .font(AppFont.inter(14, .medium))
                .foregroundStyle(isSelected ? Theme.onAccent : Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(minHeight: 44)
                .background {
                    Capsule()
                        .fill(isSelected ? Theme.accent : Color.clear)
                        .overlay {
                            if !isSelected {
                                Capsule().stroke(Theme.separator, lineWidth: 1)
                            }
                        }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct WrappingHStack: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrangement(width: proposal.width ?? .greatestFiniteMagnitude, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let plan = arrangement(width: bounds.width, subviews: subviews)
        for index in subviews.indices {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + plan.origins[index].x, y: bounds.minY + plan.origins[index].y),
                anchor: .topLeading,
                proposal: ProposedViewSize(plan.sizes[index])
            )
        }
    }

    private func arrangement(width: CGFloat, subviews: Subviews) -> (size: CGSize, origins: [CGPoint], sizes: [CGSize]) {
        let width = max(0, width)
        var origins: [CGPoint] = []
        var sizes: [CGSize] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var usedWidth: CGFloat = 0
        for subview in subviews {
            let ideal = subview.sizeThatFits(.unspecified)
            let size = ideal.width > width ? subview.sizeThatFits(ProposedViewSize(width: width, height: nil)) : ideal
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            sizes.append(size)
            usedWidth = max(usedWidth, x + size.width)
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        return (CGSize(width: usedWidth, height: y + rowHeight), origins, sizes)
    }
}

struct AdaptiveControlRow<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let content: Content

    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 10))
        layout { content }
    }
}

struct SegmentedChip: View {
    let title: String
    let isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button {
            endTextEditing()
            action()
        } label: {
            Text(L10n.string(title))
                .font(AppFont.inter(14, .medium))
                .foregroundStyle(isSelected ? Theme.onAccent : Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .frame(minHeight: 44)
                .background {
                    Capsule()
                        .fill(isSelected ? Theme.accent : Color.clear)
                        .overlay {
                            if !isSelected {
                                Capsule().stroke(Theme.separator, lineWidth: 1)
                            }
                        }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct FieldLabel: View {
    let text: String

    var body: some View {
        Text(L10n.string(text))
            .font(AppFont.inter(12, .medium))
            .foregroundStyle(Theme.secondaryText)
            .textCase(.uppercase)
            .tracking(0.5)
    }
}

struct OutlinedField: View {
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var capitalization: TextInputAutocapitalization = .sentences
    var isFocused: Bool = false
    @FocusState private var focused: Bool

    var body: some View {
        TextField(L10n.string(placeholder), text: $text)
            .focused($focused)
            .font(AppFont.inter(16))
            .foregroundStyle(Theme.primaryText)
            .keyboardType(keyboard)
            .textInputAutocapitalization(capitalization)
            .autocorrectionDisabled(keyboard == .decimalPad)
            .submitLabel(.done)
            .onSubmit { focused = false }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(minHeight: 48)
            .background(Theme.fieldBackground.opacity(0.35))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isFocused || focused ? Theme.accent : Theme.separator, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .preference(key: TextFieldFocusKey.self, value: focused)
    }
}

struct SearchFieldButton: View {
    let placeholder: String
    var action: () -> Void

    var body: some View {
        Button {
            endTextEditing()
            action()
        } label: {
            Text(L10n.string(placeholder))
                .font(AppFont.inter(16))
                .foregroundStyle(Theme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(minHeight: 48)
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Theme.separator, lineWidth: 1)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct SeparatorLine: View {
    var body: some View {
        Theme.separator.frame(height: 1)
    }
}

struct SectionTitle: View {
    let text: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(L10n.string(text))
                .font(AppFont.inter(17, .semibold))
                .foregroundStyle(Theme.primaryText)
            Spacer()
            if let actionTitle, let action {
                Button {
                    endTextEditing()
                    action()
                } label: {
                    Text(L10n.string(actionTitle))
                        .font(AppFont.inter(16, .semibold))
                        .foregroundStyle(Theme.secondaryText)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct InfoText: View {
    let text: String

    var body: some View {
        Text(L10n.string(text))
            .font(AppFont.inter(14))
            .foregroundStyle(Theme.secondaryText)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct SavedBanner: View {
    let text: String
    var undoTitle: String = "Undo"
    var undo: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            Text("✓")
                .font(AppFont.inter(16))
                .foregroundStyle(Theme.secondaryText)
            Text(L10n.string(text))
                .font(AppFont.inter(14, .medium))
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            if let undo {
                Button(L10n.string(undoTitle), action: undo)
                    .font(AppFont.inter(16, .semibold))
                    .foregroundStyle(Theme.secondaryText)
                    .buttonStyle(.plain)
                    .frame(minHeight: 44)
            }
        }
        .padding(.vertical, 2)
    }
}

struct OpenRow: View {
    let title: String
    var subtitle: String? = nil
    var value: String? = nil
    var action: () -> Void

    var body: some View {
        Button {
            endTextEditing()
            action()
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.string(title))
                        .font(AppFont.inter(16, .medium))
                        .foregroundStyle(Theme.primaryText)
                    if let subtitle {
                        Text(L10n.string(subtitle))
                            .font(AppFont.inter(14))
                            .foregroundStyle(Theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 8)
                if let value {
                    Text(L10n.string(value))
                        .font(AppFont.inter(16, .medium))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct SelectionRow: View {
    let title: String
    var subtitle: String? = nil
    let isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button {
            endTextEditing()
            action()
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                if isSelected {
                    Text("✓")
                        .font(AppFont.inter(16, .medium))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 18)
                } else {
                    Color.clear.frame(width: 18, height: 1)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.string(title))
                        .font(AppFont.inter(16, .medium))
                        .foregroundStyle(Theme.primaryText)
                    if let subtitle {
                        Text(L10n.string(subtitle))
                            .font(AppFont.inter(14))
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct FormRow: View {
    let label: String
    let value: String
    var detail: String? = nil
    var action: () -> Void

    var body: some View {
        Button {
            endTextEditing()
            action()
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.string(label))
                        .font(AppFont.inter(16, .medium))
                        .foregroundStyle(Theme.primaryText)
                    if let detail {
                        Text(L10n.string(detail))
                            .font(AppFont.inter(14))
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
                Spacer(minLength: 8)
                Text(L10n.string(value))
                    .font(AppFont.inter(15))
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct FullWidthInfoRow: View {
    let title: String
    var subtitle: String? = nil
    var trailing: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.string(title))
                    .font(AppFont.inter(16, .medium))
                    .foregroundStyle(Theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle {
                    Text(L10n.string(subtitle))
                        .font(AppFont.inter(14))
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            if let trailing {
                Text(L10n.string(trailing))
                    .font(AppFont.inter(16, .semibold))
                    .foregroundStyle(Theme.primaryText)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
}
