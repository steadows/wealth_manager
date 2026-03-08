import Foundation

/// ViewModel for user profile editing.
@Observable
final class ProfileViewModel {

    // MARK: - Published State

    var profile: UserProfile?
    var isLoading: Bool = false
    var isSaving: Bool = false
    var error: Error?

    // MARK: - Dependencies

    private let profileRepo: UserProfileRepository

    // MARK: - Init

    init(profileRepo: UserProfileRepository) {
        self.profileRepo = profileRepo
    }

    // MARK: - Actions

    /// Ensures a profile exists, loading from repo or creating a default.
    func ensureProfile() async {
        isLoading = true
        error = nil

        do {
            if let existing = try await profileRepo.fetch() {
                profile = existing
            } else {
                let newProfile = UserProfile()
                try await profileRepo.createOrUpdate(newProfile)
                profile = newProfile
            }
        } catch {
            self.error = error
        }

        isLoading = false
    }

    /// Saves the current profile to the repository.
    func saveProfile() async {
        guard let profile else { return }
        isSaving = true
        error = nil

        do {
            try await profileRepo.createOrUpdate(profile)
        } catch {
            self.error = error
        }

        isSaving = false
    }
}
