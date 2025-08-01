import Foundation

/// A delegate class for managing upload tasks in a `URLSession`.
///
/// The `IONFLTRUploadDelegate` class manages the progress, completion, and redirection of upload tasks.
/// It communicates progress, success and failure through a publisher.
/// 
/// - Note: This class conforms to `URLSessionTaskDelegate` and `URLSessionDataDelegate` to handle task-specific events.
class IONFLTRUploadDelegate: IONFLTRBaseDelegate {

    /// the URL pointing to the file to upload
    let fileURL: URL
    
    /// The total number of bytes sent during the upload.
    private var totalBytesSent: Int = 0
    
    /// The data received from the server during the upload.
    private lazy var receivedData: Data = Data()


    /// Initializes a new instance of the `IONFLTRUploadDelegate` class.
    ///
    /// - Parameters:
    ///   - publisher: The publisher used to send progress and success updates.
    ///   - disableRedirects: A flag indicating whether HTTP redirects should be disabled.
    ///   - fileURL: the URL pointing to the file to upload
    init(publisher: IONFLTRPublisher, disableRedirects: Bool, fileURL: URL) {
        self.fileURL = fileURL
        super.init(publisher: publisher, disableRedirects: disableRedirects)
    }
}

extension IONFLTRUploadDelegate: URLSessionDataDelegate {
    
    /// Reports the progress of an upload task.
    ///
    /// - Parameters:
    ///   - session: The `URLSession` containing the upload task.
    ///   - task: The `URLSessionTask` reporting progress.
    ///   - bytesSent: The number of bytes sent since the last call.
    ///   - totalBytesSent: The total number of bytes sent so far.
    ///   - totalBytesExpectedToSend: The total number of bytes expected to be sent.
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        self.totalBytesSent = Int(totalBytesSent)
        publisher.sendProgress(Int(totalBytesSent), totalBytesExpected: Int(totalBytesExpectedToSend))
    }
    
    /// Handles the completion of an upload task.
    ///
    /// - Parameters:
    ///   - session: The `URLSession` containing the task.
    ///   - task: The `URLSessionTask` that completed.
    ///   - error: The error that occurred, if any.
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        if let error = error {
            super.handleCompletion(task: task, error: error)
            return
        }
        
        let response = task.response as? HTTPURLResponse
        let statusCode = response?.statusCode ?? 0
        let responseData = String(data: receivedData, encoding: .utf8)
        let headers = response?.allHeaderFields.reduce(into: [String: String]()) { result, element in
            if let key = element.key as? String, let value = element.value as? String {
                result[key] = value
            }
        } ?? [:]
        
        if (200...299).contains(statusCode) {
            publisher.sendSuccess(
                totalBytes: totalBytesSent,
                responseCode: statusCode,
                responseBody: responseData,
                headers: headers
            )
        } else {
            publisher.sendFailure(
                IONFLTRException.httpError(
                    responseCode: statusCode,
                    responseBody: nil,
                    headers: headers
                )
            )
        }
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

    /// Handles the receipt of data during an upload task.
    ///
    /// - Parameters:
    ///   - session: The `URLSession` containing the data task.
    ///   - dataTask: The `URLSessionDataTask` that received the data.
    ///   - data: The data received from the server.
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        receivedData.append(data)
    }
    
    /// Handles sending a body stream of the file to upload. Relevant for chunkedMode=true
    ///
    /// - Parameters:
    ///   - session: The `URLSession` containing the data task.
    ///   - task: The `URLSessionTask` that wiill get the input stream
    func urlSession(_ session: URLSession, needNewBodyStreamForTask task: URLSessionTask) async -> InputStream? {
        print("needNewBodyStream")
        let stream = InputStream(fileAtPath: fileURL.path)
        return stream
    }
}
