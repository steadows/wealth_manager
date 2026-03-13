import SwiftUI

/// Onboarding step for setting an initial financial goal.
struct SetGoalStepView: View {

    let viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "target")
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            Text("Set Your First Goal")
                .font(.title2)
                .bold()

            Text("What does financial success look like for you? Setting a goal helps us give you personalised advice.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}
