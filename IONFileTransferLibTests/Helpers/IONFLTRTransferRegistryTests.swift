import XCTest
import Combine
@testable import IONFileTransferLib

final class IONFLTRTransferRegistryTests: XCTestCase {

    class MockTask: URLSessionTask, @unchecked Sendable {
        private(set) var didCallCancel = false

        override func cancel() {
            didCallCancel = true
        }
    }

    var registry: IONFLTRTransferRegistry!
    var session: URLSession!

    override func setUp() {
        super.setUp()
        registry = IONFLTRTransferRegistry()
        session = URLSession(configuration: .default)
    }

    override func tearDown() {
        registry.abortAll()
        registry = nil
        session = nil
        super.tearDown()
    }

    @discardableResult
    private func register(_ transferId: String, task: MockTask, publisher: IONFLTRPublisher) -> Bool {
        registry.register(transferId: transferId, session: session, task: task, publisher: publisher)
    }

    func testRegister_shouldTrackTransferAsInProgress() {
        let registered = register("transfer-1", task: MockTask(), publisher: IONFLTRPublisher())

        XCTAssertTrue(registered)
        XCTAssertTrue(registry.isInProgress("transfer-1"))
        XCTAssertEqual(registry.transferIdsInProgress, ["transfer-1"])
    }

    func testRegister_withIdAlreadyInProgress_shouldNotRegisterAgain() {
        let firstTask = MockTask()
        register("transfer-1", task: firstTask, publisher: IONFLTRPublisher())

        let registered = register("transfer-1", task: MockTask(), publisher: IONFLTRPublisher())

        XCTAssertFalse(registered)
        XCTAssertEqual(registry.transferIdsInProgress, ["transfer-1"])
        XCTAssertFalse(firstTask.didCallCancel, "The transfer already in progress should not be affected")
    }

    func testRegister_afterPreviousTransferCompleted_shouldReuseId() {
        let publisher = IONFLTRPublisher()
        register("transfer-1", task: MockTask(), publisher: publisher)
        publisher.sendSuccess(totalBytes: 1, responseCode: 200, responseBody: nil, headers: [:])

        let registered = register("transfer-1", task: MockTask(), publisher: IONFLTRPublisher())

        XCTAssertTrue(registered)
        XCTAssertTrue(registry.isInProgress("transfer-1"))
    }

    func testAbort_shouldCancelTaskAndStopTrackingTransfer() {
        let task = MockTask()
        register("transfer-1", task: task, publisher: IONFLTRPublisher())

        let aborted = registry.abort("transfer-1")

        XCTAssertTrue(aborted)
        XCTAssertTrue(task.didCallCancel)
        XCTAssertFalse(registry.isInProgress("transfer-1"))
    }

    func testAbort_withUnknownId_shouldDoNothing() {
        let task = MockTask()
        register("transfer-1", task: task, publisher: IONFLTRPublisher())

        let aborted = registry.abort("transfer-2")

        XCTAssertFalse(aborted)
        XCTAssertFalse(task.didCallCancel)
        XCTAssertTrue(registry.isInProgress("transfer-1"))
    }

    func testAbort_withTransferAlreadyCompleted_shouldDoNothing() {
        let task = MockTask()
        let publisher = IONFLTRPublisher()
        register("transfer-1", task: task, publisher: publisher)
        publisher.sendSuccess(totalBytes: 1, responseCode: 200, responseBody: nil, headers: [:])

        let aborted = registry.abort("transfer-1")

        XCTAssertFalse(aborted)
        XCTAssertFalse(task.didCallCancel)
    }

    func testAbortAll_shouldCancelEveryTransferInProgress() {
        let firstTask = MockTask()
        let secondTask = MockTask()
        register("transfer-1", task: firstTask, publisher: IONFLTRPublisher())
        register("transfer-2", task: secondTask, publisher: IONFLTRPublisher())

        let aborted = registry.abortAll()

        XCTAssertEqual(aborted.sorted(), ["transfer-1", "transfer-2"])
        XCTAssertTrue(firstTask.didCallCancel)
        XCTAssertTrue(secondTask.didCallCancel)
        XCTAssertTrue(registry.transferIdsInProgress.isEmpty)
    }

    func testPublisherSuccess_shouldStopTrackingTransfer() {
        let publisher = IONFLTRPublisher()
        register("transfer-1", task: MockTask(), publisher: publisher)

        publisher.sendSuccess(totalBytes: 1024, responseCode: 200, responseBody: nil, headers: [:])

        XCTAssertFalse(registry.isInProgress("transfer-1"))
    }

    func testPublisherFailure_shouldStopTrackingTransfer() {
        let publisher = IONFLTRPublisher()
        register("transfer-1", task: MockTask(), publisher: publisher)

        publisher.sendFailure(IONFLTRException.transferError(cause: nil))

        XCTAssertFalse(registry.isInProgress("transfer-1"))
    }
}
