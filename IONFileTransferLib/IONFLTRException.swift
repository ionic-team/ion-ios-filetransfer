import Foundation

/// Represents the exceptions that the File Transfer library can return.
///
/// The `IONFLTRException` enum defines various error cases that can occur during file transfer operations.
/// Some exceptions may include a cause, which provides additional context about the source of the error.
///
/// - Conforms to: `Error`, `CustomStringConvertible`, `Equatable`
public enum IONFLTRException: Error, CustomStringConvertible {
    /// Indicates that the provided file path is invalid.
    ///
    /// - Parameter path: The invalid file path, or `nil` if not provided.
    case invalidPath(path: String?)
    
    /// Indicates that the provided URL is empty or `nil`.
    ///
    /// - Parameter url: The empty or `nil` URL.
    case emptyURL(url: String?)
    
    /// Indicates that the provided URL is not valid.
    ///
    /// - Parameter url: The invalid URL.
    case invalidURL(url: String)
    
    /// Indicates that the specified file does not exist.
    ///
    /// - Parameter cause: The underlying error that caused this exception, if available.
    case fileDoesNotExist(cause: Error?)
    
    /// Indicates that a directory could not be created.
    ///
    /// - Parameters:
    ///   - path: The path where the directory could not be created.
    ///   - cause: The underlying error that caused this exception, if available.
    case cannotCreateDirectory(path: String, cause: Error?)
    
    /// Indicates an HTTP error occurred during the file transfer.
    ///
    /// - Parameters:
    ///   - responseCode: The HTTP response code.
    ///   - responseBody: The body of the HTTP response, if available.
    ///   - headers: The HTTP response headers, if available.
    case httpError(responseCode: Int, responseBody: String?, headers: [String: String]?)
    
    /// Indicates a connection error occurred.
    ///
    /// - Parameter cause: The underlying error that caused this exception, if available.
    case connectionError(cause: Error?)
    
    /// Indicates an error occurred during the file transfer process.
    ///
    /// - Parameter cause: The underlying error that caused this exception, if available.
    case transferError(cause: Error?)
    
    /// Indicates an unknown error occurred.
    ///
    /// - Parameter cause: The underlying error that caused this exception, if available.
    case unknownError(cause: Error?)
    
    /// A textual description of the exception.
    ///
    /// This property provides a human-readable description of the exception.
    public var description: String {
        switch self {
        case .invalidPath:
            return "The provided path is either null or empty."
        case .emptyURL:
            return "The provided URL is either null or empty."
        case .invalidURL:
            return "The provided URL is not valid."
        case .fileDoesNotExist:
            return "The specified file does not exist."
        case .cannotCreateDirectory(let path, _):
            return "Cannot create directory at \(path)."
        case .httpError(let responseCode, _, _):
            return "HTTP error: \(responseCode)"
        case .connectionError:
            return "Error establishing connection."
        case .transferError:
            return "Error during file transfer."
        case .unknownError:
            return "An unknown error occurred while trying to run the operation."
        }
    }
    
    /// The underlying cause of the exception, if available.
    ///
    /// This property provides additional context about the source of the error.
    var cause: Error? {
        switch self {
        case .fileDoesNotExist(let cause),
             .cannotCreateDirectory(_, let cause),
             .connectionError(let cause),
             .transferError(let cause),
             .unknownError(let cause):
            return cause
        default:
            return nil
        }
    }
}

extension IONFLTRException: Equatable {
    public static func == (lhs: IONFLTRException, rhs: IONFLTRException) -> Bool {
        return lhs.description == rhs.description &&
                lhs.cause?.localizedDescription == rhs.cause?.localizedDescription
    }
}
