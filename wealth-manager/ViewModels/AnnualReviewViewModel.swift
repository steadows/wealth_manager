import Foundation
import Observation

/// ViewModel for the Annual Review report view.
///
/// Manages year selection and triggers the year-end comprehensive analysis fetch.
@Observable
final class AnnualReviewViewModel {

    // MARK: - State

    /// The fetched annual review, or nil if not yet loaded.
    var review: AnnualReviewDTO?

    /// The year currently selected for the review.
    var selectedYear: Int

    /// True while the fetch is in progress.
    var isLoading: Bool = false

    /// Non-nil when the most recent fetch failed.
    var errorMessage: String?

    // MARK: - Dependencies

    private let advisoryService: AdvisoryServiceProtocol

    // MARK: - Init

    /// Creates a new `AnnualReviewViewModel`.
    /// - Parameter advisoryService: The advisory service used to fetch the review.
    init(advisoryService: AdvisoryServiceProtocol) {
        self.advisoryService = advisoryService
        self.selectedYear = Calendar.current.component(.year, from: Date()) - 1
    }

    // MARK: - Actions

    /// Fetches the annual review for `selectedYear`.
    func generateReview() async {
        isLoading = true
        errorMessage = nil

        do {
            review = try await advisoryService.fetchAnnualReview(year: selectedYear)
        } catch {
            errorMessage = error.localizedDescription
            review = nil
        }

        isLoading = false
    }

    /// Updates the selected year and clears any previously loaded review.
    /// - Parameter year: The new year to select.
    func selectYear(_ year: Int) {
        selectedYear = year
        review = nil
        errorMessage = nil
    }
}
