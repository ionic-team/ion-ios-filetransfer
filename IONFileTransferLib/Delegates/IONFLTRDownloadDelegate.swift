import Foundation

/// A delegate class for handling download tasks in a `URLSession`.
///
/// The `IONFLTRDownloadDelegate` class manages the progress, completion, and redirection of download tasks.
/// It communicates progress, success and failure through a publisher.
///
/// - Note: This class conforms to `URLSessionTaskDelegate` to handle task-specific events.
class IONFLTRDownloadDelegate: IONFLTRBaseDelegate {
    
    /// The destination URL where the downloaded file will be saved.
    private var destinationURL: URL

    /// The total number of bytes written during the download.
    private var totalBytesWritten: Int = 0

    /// Initializes a new instance of the `IONFLTRDownloadDelegate` class.
    ///
    /// - Parameters:
    ///   - publisher: The publisher used to send progress and success updates.
    ///   - destinationURL: The URL where the downloaded file will be saved.
    ///   - disableRedirects: A flag indicating whether HTTP redirects should be disabled. Defaults to `false`.
    init(publisher: IONFLTRPublisher, destinationURL: URL, disableRedirects: Bool = false) {
        self.destinationURL = destinationURL
        super.init(publisher: publisher, disableRedirects: disableRedirects)
    }
}

extension IONFLTRDownloadDelegate: URLSessionDownloadDelegate {
    
    /// Reports the progress of a download task.
    ///
    /// - Parameters:
    ///   - session: The `URLSession` containing the download task.
    ///   - downloadTask: The `URLSessionDownloadTask` reporting progress.
    ///   - bytesWritten: The number of bytes written since the last call.
    ///   - totalBytesWritten: The total number of bytes written so far.
    ///   - totalBytesExpectedToWrite: The total number of bytes expected to be written.
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        self.totalBytesWritten = Int(totalBytesWritten)
        publisher.sendProgress(Int(totalBytesWritten), totalBytesExpected: Int(totalBytesExpectedToWrite))
    }
    
    /// Handles the completion of a download task.
    ///
    /// - Parameters:
    ///   - session: The `URLSession` containing the download task.
    ///   - downloadTask: The `URLSessionDownloadTask` that finished downloading.
    ///   - location: The temporary file location of the downloaded file.
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        do {
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: self.destinationURL.path) {
                try fileManager.removeItem(at: self.destinationURL)
            }
            try fileManager.moveItem(at: location, to: self.destinationURL)

            let response = downloadTask.response as? HTTPURLResponse
            let statusCode = response?.statusCode ?? 0
            let headers = response?.allHeaderFields.reduce(into: [String: String]()) { result, element in
                if let key = element.key as? String, let value = element.value as? String {
                    result[key] = value
                }
            } ?? [:]
            
            publisher.sendSuccess(
                totalBytes: totalBytesWritten,
                responseCode: statusCode,
                responseBody: nil,
                headers: headers
            )
        } catch {
            publisher.sendFailure(error)
        }
    }
    
    /// Handles the completion of a download task.
    ///
    /// - Parameters:
    ///   - session: The `URLSession` containing the task.
    ///   - task: The `URLSessionTask` that completed.
    ///   - error: The error that occurred, if any.
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        super.handleCompletion(task: task, error: error)
    }
    
    /// Handles HTTP redirection for a task.
    ///
    /// - Parameters:
    ///   - session: The `URLSession` containing the task.
    ///   - task: The `URLSessionTask` that will be redirected.
    ///   - response: The `HTTPURLResponse` that caused the redirection.
    ///   - request: The new `URLRequest` to redirect to.
    ///   - completionHandler: A closure to execute with the new request or `nil` to refuse the redirect.
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        super.handleRedirect(response: response, request: request, completionHandler: completionHandler)
    }
}
