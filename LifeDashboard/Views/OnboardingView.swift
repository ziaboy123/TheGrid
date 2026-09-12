import SwiftUI

private struct OnboardingPage: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let message: String
}

private let onboardingPages: [OnboardingPage] = [
    OnboardingPage(
        icon: "square.grid.2x2.fill",
        title: "Freeform Boards",
        message: "Structure your notes however you like — collapsible sections, dividers, checklists, rich text. No forced due dates, no subscriptions."
    ),
    OnboardingPage(
        icon: "sun.max.fill",
        title: "Today, at a Glance",
        message: "See today's calendar agenda and unread mail counts the moment you open the app."
    ),
    OnboardingPage(
        icon: "lock.fill",
        title: "Locked Down",
        message: "Face ID keeps your boards private, and one tap backs everything up to your own iCloud Drive."
    ),
    OnboardingPage(
        icon: "apps.iphone",
        title: "Right From the Home Screen",
        message: "Add the widget to jump straight into any board, and pin your most-used ones to the top of the list."
    )
]

struct OnboardingView: View {
    var onFinish: () -> Void
    @State private var page = 0

    var body: some View {
        ZStack {
            GridBackground()
            VStack(spacing: 0) {
                TabView(selection: $page) {
                    ForEach(Array(onboardingPages.enumerated()), id: \.offset) { index, item in
                        pageView(item).tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                pageIndicator

                Button {
                    if page < onboardingPages.count - 1 {
                        withAnimation { page += 1 }
                    } else {
                        onFinish()
                    }
                } label: {
                    Text(page < onboardingPages.count - 1 ? "Next" : "Get Started")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(ClaudeTheme.accent)
                .padding(.horizontal, 32)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(onboardingPages.indices, id: \.self) { index in
                Circle()
                    .fill(index == page ? ClaudeTheme.accent : ClaudeTheme.border)
                    .frame(width: 7, height: 7)
            }
        }
        .padding(.top, 8)
    }

    private func pageView(_ item: OnboardingPage) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: item.icon)
                .font(.system(size: 56))
                .foregroundStyle(ClaudeTheme.accent)
            Text(item.title)
                .font(.title2.bold())
                .foregroundStyle(ClaudeTheme.textPrimary)
            Text(item.message)
                .font(.body)
                .foregroundStyle(ClaudeTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
            Spacer()
            Spacer()
        }
    }
}
