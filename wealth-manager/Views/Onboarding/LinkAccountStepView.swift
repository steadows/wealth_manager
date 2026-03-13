import SwiftUI

/// Onboarding step for linking a financial account via Plaid.
struct LinkAccountStepView: View {

    let viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "link.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            Text("Link Your Accounts")
                .font(.title2)
                .bold()

            Text("Connect your bank accounts to automatically track your net worth and cash flow. You can skip this and add accounts manually later.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}
