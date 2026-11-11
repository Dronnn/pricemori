import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var router: AppRouter
    @AppStorage("currencyCode") private var currencyCode = "AMD"
    @AppStorage("defaultSource") private var defaultSourceRaw = ObservationSource.shelf.rawValue
    @AppStorage(AppLanguage.storageKey) private var appLanguageRaw = AppLanguage.system.rawValue
    @State private var showLanguage = false
    @State private var showOnboarding = false

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .system
    }

    private var defaultSource: ObservationSource {
        ObservationSource(rawValue: defaultSourceRaw) ?? .shelf
    }

    var body: some View {
        ScreenScaffold(title: "Settings", backLabel: "Journal", topPadding: 16) {
            VStack(alignment: .leading, spacing: 0) {
                FieldLabel(text: "Preferences")
                    .padding(.top, 6)
                OpenRow(
                    title: "Language",
                    subtitle: "Switch languages without restarting the app",
                    value: appLanguage.nativeName
                ) {
                    showLanguage = true
                }
                SeparatorLine()
                OpenRow(
                    title: "Entry defaults",
                    subtitle: "Currency and observation source"
                ) {
                    router.push(.entryDefaults)
                }
                SeparatorLine()
                OpenRow(
                    title: "Show onboarding",
                    subtitle: "See the introduction from the beginning"
                ) {
                    showOnboarding = true
                }
                SeparatorLine()

                FieldLabel(text: "Your data")
                    .padding(.top, 28)
                OpenRow(
                    title: "Backup & export",
                    subtitle: "Save a full copy, export CSV or restore"
                ) {
                    router.push(.backup)
                }
                SeparatorLine()
                OpenRow(
                    title: "Archived products",
                    subtitle: "View history or resume tracking"
                ) {
                    router.push(.archivedProducts)
                }
                SeparatorLine()
                OpenRow(
                    title: "Archived stores",
                    subtitle: "Restore a hidden location"
                ) {
                    router.push(.archivedStores)
                }
                SeparatorLine()

                FieldLabel(text: "Support")
                    .padding(.top, 28)
                OpenRow(
                    title: "Support Pricemori",
                    subtitle: "Optional one-time tips"
                ) {
                    router.push(.support)
                }
                SeparatorLine()

                InfoText(text: "Appearance and text size follow your iPhone. Core recording and charts work offline.")
                    .padding(.top, 24)
            }
        }
        .fullScreenCover(isPresented: $showLanguage) {
            LanguagePickerView(selection: $appLanguageRaw)
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView {
                showOnboarding = false
            }
        }
    }
}

struct LanguagePickerView: View {
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScreenScaffold(title: "Language", backLabel: "Settings") {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(AppLanguage.allCases) { language in
                    SelectionRow(
                        title: language == .system ? L10n.string("System") : language.nativeName,
                        subtitle: language == .system ? L10n.string("Follow the iPhone setting") : nil,
                        isSelected: selection == language.rawValue
                    ) {
                        selection = language.rawValue
                        dismiss()
                    }
                    SeparatorLine()
                }
            }
        }
    }
}

struct EntryDefaultsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("currencyCode") private var currencyCode = "AMD"
    @AppStorage("defaultSource") private var defaultSourceRaw = ObservationSource.shelf.rawValue

    @State private var localCurrency = "AMD"
    @State private var localSource: ObservationSource = .shelf

    var body: some View {
        ScreenScaffold(
            title: "Entry defaults",
            backLabel: "Settings",
            footer: {
                PrimaryButton(title: "Save defaults") {
                    currencyCode = localCurrency
                    defaultSourceRaw = localSource.rawValue
                    dismiss()
                }
            }
        ) {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Currency · \(localCurrency)")
                        .font(AppFont.inter(16, .medium))
                        .foregroundStyle(Theme.primaryText)
                    Text("For new observations")
                        .font(AppFont.inter(14))
                        .foregroundStyle(Theme.secondaryText)
                    Menu {
                        ForEach(CurrencyOption.all) { option in
                            Button(option.title) { localCurrency = option.code }
                        }
                    } label: {
                        HStack {
                            Text(CurrencyOption.name(for: localCurrency))
                                .font(AppFont.inter(16))
                                .foregroundStyle(Theme.primaryText)
                            Spacer()
                            Text(localCurrency)
                                .font(AppFont.inter(16, .medium))
                                .foregroundStyle(Theme.secondaryText)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Theme.secondaryText)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .frame(minHeight: 48)
                        .overlay { RoundedRectangle(cornerRadius: 10).stroke(Theme.separator) }
                        .contentShape(Rectangle())
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    FieldLabel(text: "Default observation source")
                    ForEach(ObservationSource.allCases) { option in
                        SelectionRow(title: option.title, isSelected: localSource == option) {
                            localSource = option
                        }
                    }
                }

                InfoText(text: "Existing prices keep their currency and source. A different currency never converts a saved amount automatically.")

                InfoText(text: "Date defaults to today. Product and branch come from your current task. Previous package details remain visible and editable.")
            }
            .onAppear {
                localCurrency = currencyCode
                localSource = ObservationSource(rawValue: defaultSourceRaw) ?? .shelf
            }
        }
    }
}
