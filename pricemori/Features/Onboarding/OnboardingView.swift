import SwiftUI

enum Onboarding {
    static let storageKey = "hasCompletedOnboarding"
}

struct OnboardingView: View {
    var onFinish: () -> Void

    @State private var selection = 0

    private let pages = [
        OnboardingPage(
            icon: "book.closed",
            title: "Your own price journal",
            body: "Write down what something cost at the shops you actually use."
        ),
        OnboardingPage(
            icon: "chart.xyaxis.line",
            title: "Collect price statistics",
            body: "Over time you build your own history: dates, stores, and honest comparisons."
        ),
        OnboardingPage(
            icon: "lock",
            title: "Private and offline",
            body: "No account, no cloud, no ads. Your journal stays on this device."
        )
    ]

    private var isLastPage: Bool {
        selection == pages.count - 1
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer(minLength: 0)
                Button(action: onFinish) {
                    Text(L10n.string("Skip"))
                        .font(AppFont.inter(15, .medium))
                        .foregroundStyle(Theme.secondaryText)
                        .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("onboarding.skip")
            }
            .padding(.horizontal, 24)

            TabView(selection: $selection) {
                ForEach(pages.indices, id: \.self) { index in
                    OnboardingPageView(page: pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 8) {
                ForEach(pages.indices, id: \.self) { index in
                    Circle()
                        .fill(index == selection ? Theme.accent : Theme.separator)
                        .frame(width: 7, height: 7)
                }
            }
            .padding(.bottom, 22)

            PrimaryButton(title: isLastPage ? "Get started" : "Next") {
                if isLastPage {
                    onFinish()
                } else {
                    withAnimation { selection += 1 }
                }
            }
            .accessibilityIdentifier("onboarding.next")
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
        .background(Theme.background.ignoresSafeArea())
    }
}

private struct OnboardingPage {
    let icon: String
    let title: String
    let body: String
}

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: page.icon)
                    .font(.system(size: 30, weight: .regular))
                    .foregroundStyle(Theme.accent)

                Text(L10n.string(page.title))
                    .font(AppFont.serif(36))
                    .foregroundStyle(Theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 28)

                Text(L10n.string(page.body))
                    .font(AppFont.inter(17))
                    .foregroundStyle(Theme.secondaryText)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 16)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
    }
}
