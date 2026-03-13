import SwiftUI

/// First onboarding step — introduces the app to new users.
struct WelcomeStepView: View {

    let viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            Text("Welcome to Wealth Manager")
                .font(.largeTitle)
                .bold()

            Text("Your personal CFO, right on your Mac. Let's set up your financial profile in a few quick steps.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}
