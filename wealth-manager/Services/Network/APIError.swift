import Foundation

/// Errors that can occur during API communication.
enum APIError: Error, LocalizedError {
    case invalidURL
    case unauthorized
    case serverError(statusCode: Int, message: String)
    case apiError(message: String)
    case decodingError(Error)
    case networkError(Error)
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .unauthorized:
            return "Authentication required. Please sign in again."
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        case .apiError(let message):
            return message
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error):
            if let urlError = error as? URLError {
                switch urlError.code {
                case .cannotConnectToHost, .timedOut:
                    #if DEBUG
                    return "Cannot reach backend server. Run: conda run -n wealth-manager uvicorn app.main:app --reload --host 127.0.0.1 --port 8000"
                    #else
                    return "Cannot connect to server. Please check your internet connection and try again."
                    #endif
                case .notConnectedToInternet:
                    return "No internet connection. Please check your network settings."
                default:
                    break
                }
            }
            return "Network error: \(error.localizedDescription)"
        case .noData:
            return "No data received from server"
        }
    }
}
