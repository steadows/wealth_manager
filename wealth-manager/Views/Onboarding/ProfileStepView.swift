import SwiftUI

/// Onboarding step for collecting basic profile information.
struct ProfileStepView: View {

    @Bindable var viewModel: OnboardingViewModel

    @State private var ageText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Tell us about yourself")
                .font(.title2)
                .bold()

            VStack(alignment: .leading, spacing: 8) {
                Text("Name").font(.callout).foregroundStyle(.secondary)
                TextField("Your name", text: $viewModel.profileName)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Age").font(.callout).foregroundStyle(.secondary)
                TextField("Your age", text: $ageText)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: ageText) { _, newValue in
                        viewModel.profileAge = Int(newValue)
                    }
            }

            if let error = viewModel.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }
}
