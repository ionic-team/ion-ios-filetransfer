import Foundation
import Combine

/// A custom Combine publisher for handling file transfer operations.
///
/// The `IONFLTRPublisher` class is a Combine publisher that emits events related to file transfer operations,
/// such as progress updates and completion results. It provides methods to send progress updates, success results,
/// and completion events to its subscribers.
public class IONFLTRPublisher: Publisher {
    
    /// The type of output emitted by the publisher.
    public typealias Output = IONFLTRTransferResult
    
    /// The type of error that the publisher can emit.
    public typealias Failure = Error
    
    /// A subject that acts as the underlying publisher for emitting events.
    private let subject = PassthroughSubject<Output, Failure>()
    
    /// Attaches the specified subscriber to the publisher.
    ///
    /// - Parameter subscriber: The subscriber to attach to the publisher.
    public func receive<S>(subscriber: S) where S : Subscriber, any Failure == S.Failure, Output == S.Input {
        subject.receive(subscriber: subscriber)
    }
    
    /// Sends a progress update to the subscribers.
    ///
    /// - Parameters:
    ///   - totalBytes: The number of bytes transferred so far.
    ///   - totalBytesExpected: The total number of bytes expected to be transferred.
    func sendProgress(_ totalBytes: Int, totalBytesExpected: Int) {
        let status = IONFLTRProgressStatus(bytes: totalBytes, contentLength: totalBytesExpected, lengthComputable: true)
        subject.send(.ongoing(status: status))
    }
    
    /// Sends a success result to the subscribers and completes the publisher.
    ///
    /// - Parameters:
    ///   - totalBytes: The total number of bytes transferred.
    ///   - responseCode: The HTTP response code from the server.
    ///   - responseBody: The response body as a string, if available.
    ///   - headers: The HTTP headers from the response.
    func sendSuccess(totalBytes: Int, responseCode: Int, responseBody: String?, headers: [String: String]) {
        let result = IONFLTRTransferComplete(totalBytes: totalBytes, responseCode: responseCode, responseBody: responseBody, headers: headers)
        subject.send(.complete(data: result))
        subject.send(completion: .finished)
    }
    
    /// Sends a failure event to the subscribers and completes the publisher.
    ///
    /// The `sendFailure(_:)` method is used to notify subscribers of an error that occurred during
    /// the file transfer operation. It maps the provided error to an `IONFLTRException` and sends
    /// it as a failure event. After sending the failure, the publisher is completed.
    ///
    /// - Parameter error: The error that caused the failure.
    /// - Note: This method ensures that subscribers are informed of the failure and that no further events
    ///   will be emitted by the publisher.
    func sendFailure(_ error: Error) {
        subject.send(completion: .failure(mapErrorToIONFLTRException(error)))
    }
}
