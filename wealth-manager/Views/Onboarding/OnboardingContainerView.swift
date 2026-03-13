import SwiftUI

/// Root container for the onboarding wizard. Renders the active step
/// and displays a progress bar across all steps.
struct OnboardingContainerView: View {

    @State private var viewModel: OnboardingViewModel

    init(service: any OnboardingServiceProtocol = OnboardingService()) {
        _viewModel = State(initialValue: OnboardingViewModel(service: service))
    }

    var body: some View {
        VStack(spacing: 0) {
            ProgressView(value: viewModel.progressFraction)
                .padding(.horizontal)
                .padding(.top)

            stepView
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            navigationButtons
                .padding()
        }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 360)
        #endif
    }

    // MARK: - Private

    @ViewBuilder
    private var stepView: some View {
        switch viewModel.currentStep {
        case .welcome:
            WelcomeStepView(viewModel: viewModel)
        case .profile:
            ProfileStepView(viewModel: viewModel)
        case .linkAccount:
            LinkAccountStepView(viewModel: viewModel)
        case .setGoal:
            SetGoalStepView(viewModel: viewModel)
        case .complete:
            Text("Setup complete!")
                .font(.title2)
        }
    }

    private var navigationButtons: some View {
        HStack {
            if viewModel.currentStep != .welcome {
                Button("Back") { viewModel.previousStep() }
                    .buttonStyle(.bordered)
            }

            Spacer()

            if viewModel.currentStep != .complete {
                Button("Skip") { viewModel.skipStep() }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)

                Button("Continue") { viewModel.nextStep() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.canAdvance)
            } else {
                Button("Get Started") { viewModel.completeOnboarding() }
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}
