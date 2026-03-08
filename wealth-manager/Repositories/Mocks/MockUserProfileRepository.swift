import Foundation

final class MockUserProfileRepository: UserProfileRepository {
    var profile: UserProfile?

    func fetch() async throws -> UserProfile? {
        profile
    }

    func createOrUpdate(_ profile: UserProfile) async throws {
        self.profile = profile
    }
}
