import Foundation

/// A base delegate class for common upload and download task behaviors in a `URLSession`.
///
/// `IONFLTRBaseDelegate` provides shared logic for handling task completion and HTTP redirection.
/// It is intended to be subclassed by specific delegates like `IONFLTRDownloadDelegate` and `IONFLTRUploadDelegate`.
///
/// This class communicates progress, success, and failure through a provided `IONFLTRPublisher`.
///
/// - Note: This class does not conform to any URLSession delegate protocols directly. Subclasses should conform to the appropriate protocols as needed.
class IONFLTRBaseDelegate: NSObject {

    /// The publisher used to send progress, success, and failure updates.
    let publisher: IONFLTRPublisher

    /// A flag indicating whether HTTP redirects should be disabled.
    let disableRedirects: Bool

    /// Initializes a new instance of the `IONFLTRBaseDelegate` class.
    ///
    /// - Parameters:
    ///   - publisher: The publisher used to communicate task updates.
    ///   - disableRedirects: A flag indicating whether HTTP redirects should be disabled. Defaults to `false`.
    init(publisher: IONFLTRPublisher, disableRedirects: Bool = false) {
        self.publisher = publisher
        self.disableRedirects = disableRedirects
    }

    /// Handles the completion of a URL session task.
    ///
    /// This method checks for errors and evaluates the HTTP response. If the response code indicates a failure (non-2xx),
    /// it emits a failure event through the publisher with a structured `IONFLTRException`.
    ///
    /// - Parameters:
    ///   - task: The `URLSessionTask` that completed.
    ///   - error: The error that occurred, if any.
    ///   - responseBody: The optional response body to include in the error, if available.
    func handleCompletion(task: URLSessionTask, error: Error?, responseBody: String? = nil) {
        if let error = error {
            publisher.sendFailure(error)
            return
        }

        guard let response = task.response as? HTTPURLResponse,
              !(200...299).contains(response.statusCode) else {
            return
        }

        let headers = response.allHeaderFields.reduce(into: [String: String]()) { result, element in
            if let key = element.key as? String, let value = element.value as? String {
                result[key] = value
            }
        }

        publisher.sendFailure(
            IONFLTRException.httpError(
                responseCode: response.statusCode,
                responseBody: responseBody,
                headers: headers
            )
        )
    }

    /// Handles HTTP redirection behavior.
    ///
    /// This method determines whether or not to allow an HTTP redirect based on the `disableRedirects` flag.
    ///
    /// - Parameters:
    ///   - response: The `HTTPURLResponse` that triggered the redirection.
    ///   - request: The new `URLRequest` to which the task is being redirected.
    ///   - completionHandler: A closure that receives the request to continue with or `nil` to block the redirect.
    func handleRedirect(
        response: HTTPURLResponse,
        request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(disableRedirects ? nil : request)
    }
}
