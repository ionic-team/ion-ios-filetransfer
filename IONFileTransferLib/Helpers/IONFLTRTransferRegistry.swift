import Foundation
import Combine

/// Keeps track of the file transfers that are currently in progress, so that they can be aborted.
///
/// Each transfer is identified by an identifier and holds the `URLSession` and `URLSessionTask` running it.
/// Entries are removed automatically as soon as the associated `IONFLTRPublisher` completes, which also
/// invalidates the session so that it doesn't outlive the transfer it was created for.
///
/// - Note: All accesses to the underlying storage are serialized, making this class safe to use from multiple threads.
class IONFLTRTransferRegistry {

    /// The information required to keep track of - and abort - a single transfer.
    private struct Transfer {
        /// The session running the transfer. Each transfer owns a session, so invalidating it affects no other one.
        let session: URLSession

        /// The task running the transfer.
        let task: URLSessionTask

        /// The subscription used to detect the end of the transfer. Set right after the transfer is registered.
        var cancellable: AnyCancellable?
    }

    /// The transfers currently in progress, keyed by their identifier.
    private var transfers: [String: Transfer] = [:]

    /// The queue used to serialize accesses to `transfers`.
    private let queue = DispatchQueue(label: "com.outsystems.ionfltr.transferRegistry")

    /// The identifiers of all the transfers that are currently in progress.
    var transferIdsInProgress: [String] {
        queue.sync { Array(transfers.keys) }
    }

    /// Indicates whether the transfer with the given identifier is currently in progress.
    ///
    /// - Parameter transferId: The identifier of the transfer to look for.
    /// - Returns: `true` if the transfer is in progress, `false` otherwise.
    func isInProgress(_ transferId: String) -> Bool {
        queue.sync { transfers[transferId] != nil }
    }

    /// Registers a transfer so that it can later be aborted through `abort(_:)` or `abortAll()`.
    ///
    /// The transfer is automatically unregistered - and its session invalidated - once `publisher` completes,
    /// either successfully or with a failure.
    ///
    /// - Parameters:
    ///   - transferId: The identifier to register the transfer under.
    ///   - session: The session running the transfer.
    ///   - task: The task running the transfer.
    ///   - publisher: The publisher reporting the outcome of the transfer.
    /// - Returns: `false` if a transfer with the same identifier is already in progress, `true` otherwise.
    /// - Note: This should be called before the task is resumed, so that the transfer can be aborted at any point.
    func register(transferId: String, session: URLSession, task: URLSessionTask, publisher: IONFLTRPublisher) -> Bool {
        let registered = queue.sync { () -> Bool in
            guard transfers[transferId] == nil else { return false }
            transfers[transferId] = Transfer(session: session, task: task, cancellable: nil)
            return true
        }
        guard registered else { return false }

        let cancellable = publisher.sink(receiveCompletion: { [weak self] _ in
            self?.finish(transferId)
        }, receiveValue: { _ in })

        queue.sync {
            // The transfer may have finished - and therefore been replaced - while subscribing to the publisher.
            guard transfers[transferId]?.task === task else { return }
            transfers[transferId]?.cancellable = cancellable
        }
        return true
    }

    /// Aborts the transfer with the given identifier, if it is in progress.
    ///
    /// The task is cancelled, which makes its delegate report an `IONFLTRException.transferAborted` failure
    /// through the publisher, and the session is invalidated once that failure is delivered.
    ///
    /// - Parameter transferId: The identifier of the transfer to abort.
    /// - Returns: `true` if the transfer was in progress and was aborted, `false` otherwise.
    @discardableResult
    func abort(_ transferId: String) -> Bool {
        guard let transfer = queue.sync(execute: { transfers.removeValue(forKey: transferId) }) else { return false }
        cancel(transfer)
        return true
    }

    /// Aborts all the transfers that are currently in progress.
    ///
    /// - Returns: The identifiers of the transfers that were aborted.
    @discardableResult
    func abortAll() -> [String] {
        let aborted = queue.sync { () -> [String: Transfer] in
            let all = transfers
            transfers.removeAll()
            return all
        }
        aborted.values.forEach(cancel)
        return Array(aborted.keys)
    }

    /// Unregisters a transfer that reached its end on its own, invalidating its session.
    ///
    /// - Parameter transferId: The identifier of the transfer that finished.
    private func finish(_ transferId: String) {
        let transfer = queue.sync { transfers.removeValue(forKey: transferId) }
        transfer?.session.finishTasksAndInvalidate()
    }

    /// Cancels a transfer's task and invalidates its session once the cancellation is reported to the delegate.
    ///
    /// - Parameter transfer: The transfer to cancel.
    private func cancel(_ transfer: Transfer) {
        transfer.task.cancel()
        transfer.session.finishTasksAndInvalidate()
    }
}
