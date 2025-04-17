import XCTest
import Combine
@testable import IONFileTransferLib

final class IONFLTRDownloadPublisherTests: XCTestCase {

    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        cancellables = []
    }

    override func tearDown() {
        cancellables = nil
        super.tearDown()
    }

    func testSendProgress_shouldEmitOngoingTransferResult() {
        let publisher = IONFLTRPublisher()
        let expectation = XCTestExpectation(description: "Should emit ongoing progress")

        let expectedBytesWritten: Int = 1024
        let expectedTotalBytes: Int = 2048

        publisher
            .sink(receiveCompletion: { _ in },
                  receiveValue: { result in
                if case let .ongoing(status) = result {
                    XCTAssertEqual(status.bytes, expectedBytesWritten)
                    XCTAssertEqual(status.contentLength, expectedTotalBytes)
                    XCTAssertTrue(status.lengthComputable)
                    expectation.fulfill()
                } else {
                    XCTFail("Expected .ongoing status, but received different result")
                }
            })
            .store(in: &cancellables)

        publisher.sendProgress(expectedBytesWritten, totalBytesExpected: expectedTotalBytes)

        wait(for: [expectation], timeout: 1)
    }

    func testSendSuccess_shouldEmitCompleteAndFinish() {
        let publisher = IONFLTRPublisher()
        let valueExpectation = XCTestExpectation(description: "Should emit .complete result")
        let finishedExpectation = XCTestExpectation(description: "Should complete with .finished")

        let expectedData = IONFLTRTransferComplete(
            totalBytes: 4096,
            responseCode: 200,
            responseBody: "OK",
            headers: ["Content-Type": "application/json"]
        )

        publisher
            .sink(receiveCompletion: { completion in
                if case .finished = completion {
                    finishedExpectation.fulfill()
                }
            }, receiveValue: { result in
                if case let .complete(data) = result {
                    XCTAssertEqual(data, expectedData)
                    valueExpectation.fulfill()
                } else {
                    XCTFail("Expected .complete status, but received different result")
                }
            })
            .store(in: &cancellables)

        publisher.sendSuccess(
            totalBytes: expectedData.totalBytes,
            responseCode: expectedData.responseCode,
            responseBody: expectedData.responseBody,
            headers: expectedData.headers
        )

        wait(for: [valueExpectation, finishedExpectation], timeout: 1)
    }
    
    func testSendFailure_emitsMappedIONFLTRExceptionAndFinishes() {
        let publisher = IONFLTRPublisher()
        let expectedError = NSError(domain: "test", code: 1, userInfo: nil)
        let expectation = XCTestExpectation(description: "Failure received")
                   
        var receivedCompletion: Subscribers.Completion<Error>?

        publisher
            .sink(
                receiveCompletion: { completion in
                    receivedCompletion = completion
                    expectation.fulfill()
                },
                receiveValue: { _ in
                    XCTFail("No value should be received")
                }
            )
            .store(in: &cancellables)

        publisher.sendFailure(expectedError)

        wait(for: [expectation], timeout: 1.0)
        
        guard case let .failure(error)? = receivedCompletion else {
            return XCTFail("Expected a failure completion")
        }

        XCTAssertTrue(error is IONFLTRException, "Expected error to be of type IONFLTRException")
     }
}
