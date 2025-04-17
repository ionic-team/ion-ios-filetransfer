import Foundation

/// Maps a given error to an `IONFLTRException`.
///
/// The `mapErrorToIONFLTRException(_:)` method takes an error as input and converts it into
/// a corresponding `IONFLTRException`. This ensures that all errors are standardized and
/// handled consistently within the file transfer operations.
///
/// - Parameter error: The error to be mapped.
/// - Returns: An `IONFLTRException` that corresponds to the provided error.
/// - Note: This method is used internally to ensure uniform error handling across the system.
func mapErrorToIONFLTRException(_ error: Error) -> IONFLTRException {
    switch error {
    case let e as IONFLTRException:
        return e
    case let e as CocoaError where (e as NSError).code == NSFileNoSuchFileError:
        return .fileDoesNotExist(cause: e)
    case let e as URLError:
        switch e.code {
        case .notConnectedToInternet, .timedOut:
            return .connectionError(cause: e)
        default:
            return .transferError(cause: e)
        }
    case let e as NSError where e.domain == NSURLErrorDomain:
        return .transferError(cause: e)
    default:
        return .unknownError(cause: error)
    }
}
