import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage: Int = 0
    @State private var appeared = false

    private let pages: [(icon: String, title: String, subtitle: String)] = [
        ("shoe.2.fill", "Know Your Footwear", "Track real-world wear across every pair you own — walking shoes, boots, sandals, and everything in between."),
        ("figure.walk", "Powered by Your Steps", "Tread reads your movement data from Apple Health and turns it into footwear intelligence — no manual logging needed."),
        ("chart.line.uptrend.xyaxis", "Lifecycle Clarity", "See which pairs are overused, which are neglected, and when it's time to retire or replace.")
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    VStack(spacing: 24) {
                        ZStack {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [Color.primary.opacity(0.08), Color.primary.opacity(0.02)],
                                        center: .center,
                                        startRadius: 20,
                                        endRadius: 70
                                    )
                                )
                                .frame(width: 140, height: 140)

                            Image(systemName: page.icon)
                                .font(.system(size: 48, weight: .medium))
                                .foregroundStyle(.primary)
                                .symbolEffect(.bounce, value: currentPage == index)
                        }
                        .opacity(appeared ? 1 : 0)
                        .scaleEffect(appeared ? 1 : 0.8)

                        VStack(spacing: 10) {
                            Text(page.title)
                                .font(.title2.bold())
                                .multilineTextAlignment(.center)

                            Text(page.subtitle)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(2)
                        }
                        .padding(.horizontal, 32)
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 360)

            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Capsule()
                        .fill(currentPage == index ? Color.primary : Color.primary.opacity(0.15))
                        .frame(width: currentPage == index ? 24 : 8, height: 8)
                        .animation(.snappy, value: currentPage)
                }
            }
            .padding(.top, 24)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    withAnimation(.snappy) {
                        hasCompletedOnboarding = true
                    }
                } label: {
                    Text(currentPage == pages.count - 1 ? "Get Started" : "Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .tint(.primary)

                if currentPage < pages.count - 1 {
                    Button("Skip") {
                        withAnimation(.snappy) {
                            hasCompletedOnboarding = true
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6)) {
                appeared = true
            }
        }
        .sensoryFeedback(.selection, trigger: currentPage)
    }
}
