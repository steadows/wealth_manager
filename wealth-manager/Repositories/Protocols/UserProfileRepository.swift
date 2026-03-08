import Foundation

protocol UserProfileRepository {
    func fetch() async throws -> UserProfile?
    func createOrUpdate(_ profile: UserProfile) async throws
}
