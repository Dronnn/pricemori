import SwiftUI

struct ScreenScaffold<Content: View, Footer: View, Trailing: View>: View {
    let title: String?
    let backLabel: String?
    let showsBackChevron: Bool
    let backAction: (() -> Void)?
    let trailing: Trailing
    let footer: Footer
    let content: Content
    let topPadding: CGFloat

    init(
        title: String? = nil,
        backLabel: String? = nil,
        showsBackChevron: Bool = true,
        backAction: (() -> Void)? = nil,
        topPadding: CGFloat = 10,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() },
        @ViewBuilder footer: () -> Footer = { EmptyView() },
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.backLabel = backLabel
        self.showsBackChevron = showsBackChevron
        self.backAction = backAction
        self.trailing = trailing()
        self.footer = footer()
        self.content = content()
        self.topPadding = topPadding
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
            ScrollView {
                content
                    .padding(.horizontal, 24)
                    .padding(.top, topPadding)
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollIndicators(.hidden)

            if !(footer is EmptyView) {
                VStack(spacing: 0) {
                    footer
                        .padding(.horizontal, 24)
                        .padding(.top, 10)
                        .padding(.bottom, 8)
                }
                .background(Theme.background)
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct ScreenHeader: View {
    let title: String?
    var backLabel: String? = nil
    var showsBackChevron: Bool = true
    var backAction: (() -> Void)? = nil
    var trailing: AnyView = AnyView(EmptyView())

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if let title {
                    Text(title)
                        .font(AppFont.inter(17, .semibold))
                        .foregroundStyle(Theme.primaryText)
                        .lineLimit(1)
                }
                HStack(spacing: 0) {
                    if backAction != nil || backLabel != nil {
                        Button {
                            if let backAction { backAction() } else { dismiss() }
                        } label: {
                            HStack(spacing: 6) {
                                if showsBackChevron {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 15, weight: .semibold))
                                }
                                if let backLabel {
                                    Text(backLabel)
                                        .font(AppFont.inter(15, .medium))
                                }
                            }
                            .foregroundStyle(Theme.primaryText)
                            .frame(width: 130, height: 44, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer(minLength: 0)
                    trailing
                        .frame(minWidth: 56, minHeight: 44, alignment: .trailing)
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 58)
            Theme.separator
                .frame(height: 1)
        }
        .background(Theme.background)
    }
}

struct PrimaryButton: View {
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.inter(16, .semibold))
                .foregroundStyle(Theme.onAccent)
                .multilineTextAlignment(.center)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct SecondaryButton: View {
    let title: String
    var color: Color = Theme.secondaryText
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
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
        Button(action: action) {
            Text(title)
                .font(AppFont.inter(14, .medium))
                .foregroundStyle(isSelected ? Theme.onAccent : Theme.secondaryText)
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

struct SegmentedChip: View {
    let title: String
    let isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.inter(14, .medium))
                .foregroundStyle(isSelected ? Theme.onAccent : Theme.secondaryText)
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
        Text(text.uppercased())
            .font(AppFont.inter(12, .medium))
            .foregroundStyle(Theme.secondaryText)
            .tracking(0.5)
    }
}

struct OutlinedField: View {
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var capitalization: TextInputAutocapitalization = .sentences
    var isFocused: Bool = false

    var body: some View {
        TextField(placeholder, text: $text)
            .font(AppFont.inter(16))
            .foregroundStyle(Theme.primaryText)
            .keyboardType(keyboard)
            .textInputAutocapitalization(capitalization)
            .autocorrectionDisabled(keyboard == .decimalPad)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(minHeight: 48)
            .background(Theme.fieldBackground.opacity(0.35))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isFocused ? Theme.accent : Theme.separator, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct SearchFieldButton: View {
    let placeholder: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(placeholder)
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
            Text(text)
                .font(AppFont.inter(17, .semibold))
                .foregroundStyle(Theme.primaryText)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(AppFont.inter(16, .semibold))
                    .foregroundStyle(Theme.secondaryText)
                    .buttonStyle(.plain)
            }
        }
    }
}

struct InfoText: View {
    let text: String

    var body: some View {
        Text(text)
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
            Text(text)
                .font(AppFont.inter(14, .medium))
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(2)
            Spacer(minLength: 8)
            if let undo {
                Button(undoTitle, action: undo)
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
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(AppFont.inter(16, .medium))
                        .foregroundStyle(Theme.primaryText)
                    if let subtitle {
                        Text(subtitle)
                            .font(AppFont.inter(14))
                            .foregroundStyle(Theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 8)
                if let value {
                    Text(value)
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
        Button(action: action) {
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
                    Text(title)
                        .font(AppFont.inter(16, .medium))
                        .foregroundStyle(Theme.primaryText)
                    if let subtitle {
                        Text(subtitle)
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
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                        .font(AppFont.inter(16, .medium))
                        .foregroundStyle(Theme.primaryText)
                    if let detail {
                        Text(detail)
                            .font(AppFont.inter(14))
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
                Spacer(minLength: 8)
                Text(value)
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
                Text(title)
                    .font(AppFont.inter(16, .medium))
                    .foregroundStyle(Theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle {
                    Text(subtitle)
                        .font(AppFont.inter(14))
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            if let trailing {
                Text(trailing)
                    .font(AppFont.inter(16, .semibold))
                    .foregroundStyle(Theme.primaryText)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
}
