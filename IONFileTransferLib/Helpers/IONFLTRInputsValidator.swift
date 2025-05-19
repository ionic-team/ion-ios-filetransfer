import Foundation

/// A utility class for validating input parameters.
///
/// The `IONFLTRInputsValidator` class provides methods to validate various input parameters
/// such as server URLs, file paths, and other required fields. It ensures that the inputs meet
/// the expected criteria before proceeding with operations.
///
/// - Note: This class is used internally to prevent invalid inputs from causing runtime errors.
class IONFLTRInputsValidator {

    /// Validates the transfer inputs, including the server URL and file URL.
    ///
    /// This method checks if the server URL is non-empty, properly encoded, and valid.
    /// It also ensures that the file URL is valid and points to a file path.
    ///
    /// - Parameters:
    ///   - serverURL: The server `URL` to validate.
    ///   - fileURL: The file `URL` to validate.
    /// - Throws:
    ///   - `IONFLTRException.emptyURL` if the server URL is empty.
    ///   - `IONFLTRException.invalidURL` if the server URL is invalid.
    ///   - `IONFLTRException.invalidPath` if the file URL is invalid.
    func validateTransferInputs(serverURL: URL, fileURL: URL) throws {
        if serverURL.absoluteString.removingPercentEncoding?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
            throw IONFLTRException.emptyURL(url: serverURL.absoluteString)
        }
        if !isURLValid(url: serverURL) {
            throw IONFLTRException.invalidURL(url: serverURL.absoluteString)
        }
        if !isFileURLValid(url: fileURL) {
            throw IONFLTRException.invalidPath(path: fileURL.path)
        }
    }

    /// Checks if a file URL is valid.
    ///
    /// This method verifies that the provided URL is a valid file URL.
    ///
    /// - Parameter url: The file `URL` to check.
    /// - Returns: `true` if the URL is a valid file URL, `false` otherwise.
    private func isFileURLValid(url: URL) -> Bool {
        guard url.isFileURL else { return false }
        return true
    }

    /// Checks if a given URL is valid.
    ///
    /// This method ensures that the URL has a valid scheme (HTTP or HTTPS) and a host.
    ///
    /// - Parameter url: The `URL` to check.
    /// - Returns: `true` if the URL is valid, `false` otherwise.
    func isURLValid(url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
            return false
        }
        guard url.host != nil else {
            return false
        }
        return true
    }
}
