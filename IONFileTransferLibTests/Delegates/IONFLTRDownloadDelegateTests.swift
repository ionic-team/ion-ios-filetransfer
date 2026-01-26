import XCTest
@testable import IONFileTransferLib

final class IONFLTRDownloadDelegateTests: XCTestCase {

    class MockPublisher: IONFLTRPublisher {
        var progressCalled: (totalBytesWritten: Int, totalBytesExpectedToWrite: Int)?
        var successCalled: (totalBytes: Int, responseCode: Int, responseBody: String?, headers: [String: String])?
        var failureCalled: Error?

        override func sendProgress(_ totalBytesWritten: Int, totalBytesExpected totalBytesExpectedToWrite: Int) {
            progressCalled = (totalBytesWritten, totalBytesExpectedToWrite)
        }

        override func sendSuccess(totalBytes: Int, responseCode: Int, responseBody: String?, headers: [String: String]) {
            successCalled = (totalBytes, responseCode, responseBody, headers)
        }
        
        override func sendFailure(_ error: any Error) {
            failureCalled = error
        }
    }
    
    var mockPublisher: MockPublisher!
    var delegate: IONFLTRDownloadDelegate!
    var destinationURL = URL(fileURLWithPath: "/tmp/destination")

    override func setUp() {
        super.setUp()
        mockPublisher = MockPublisher()
        delegate = IONFLTRDownloadDelegate(
            publisher: mockPublisher,
            destinationURL: destinationURL
        )
    }
    
    func testDidWriteData_shouldSendProgress() {
        class MockDownloadTask: URLSessionDownloadTask, @unchecked Sendable {
            private let mockResponse: URLResponse?

            init(response: URLResponse?) {
                self.mockResponse = response
                super.init()
            }

            override var response: URLResponse? {
                return mockResponse
            }
        }
        
        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://example.com/file")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        let mockTask = MockDownloadTask(response: mockResponse)
        
        delegate.urlSession(
            URLSession.shared,
            downloadTask: mockTask,
            didWriteData: 50,
            totalBytesWritten: 150,
            totalBytesExpectedToWrite: 300
        )

        XCTAssertEqual(mockPublisher.progressCalled?.totalBytesWritten, 150)
        XCTAssertEqual(mockPublisher.progressCalled?.totalBytesExpectedToWrite, 300)
    }

    func testDidFinishDownloadingTo_shouldSendSuccess() {
        class MockDownloadTask: URLSessionDownloadTask, @unchecked Sendable {
            private let mockResponse: URLResponse?

            init(response: URLResponse?) {
                self.mockResponse = response
                super.init()
            }

            override var response: URLResponse? {
                return mockResponse
            }
        }
        
        let destinationURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let tempSourceURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)

        // Create dummy file to move
        FileManager.default.createFile(atPath: tempSourceURL.path, contents: Data("test".utf8), attributes: nil)

        let mockResponse = HTTPURLResponse(url: destinationURL, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])
        let mockTask = MockDownloadTask(response: mockResponse)

        delegate.urlSession(URLSession.shared, downloadTask: mockTask, didFinishDownloadingTo: tempSourceURL)

        XCTAssertEqual(mockPublisher.successCalled?.responseCode, 200)
        XCTAssertEqual(mockPublisher.successCalled?.headers["Content-Type"], "application/json")
    }

    func testDidCompleteWithError_shouldSendFailure() {
        let error = NSError(domain: "test", code: 1, userInfo: nil)
        delegate.urlSession(URLSession.shared, task: URLSessionDataTask(), didCompleteWithError: error)

        XCTAssertEqual(mockPublisher.failureCalled as NSError?, error)
    }

    func testWillPerformRedirect_disableRedirectsTrue_shouldCancelRedirect() {
        let delegate = IONFLTRDownloadDelegate(
            publisher: mockPublisher,
            destinationURL: destinationURL,
            disableRedirects: true
        )

        let expectation = XCTestExpectation(description: "Redirect handler called")
        delegate.urlSession(
            URLSession.shared,
            task: URLSessionDataTask(),
            willPerformHTTPRedirection: HTTPURLResponse(),
            newRequest: URLRequest(url: URL(string: "https://redirect")!),
            completionHandler: { request in
                XCTAssertNil(request)
                expectation.fulfill()
            })

        wait(for: [expectation], timeout: 1.0)
    }

    func testWillPerformRedirect_disableRedirectsFalse_shouldFollowRedirect() {
        let redirectURL = URL(string: "https://example.com")!
        let redirectRequest = URLRequest(url: redirectURL)

        let delegate = IONFLTRDownloadDelegate(
            publisher: mockPublisher,
            destinationURL: destinationURL,
            disableRedirects: false
        )

        let expectation = XCTestExpectation(description: "Redirect handler called")
        delegate.urlSession(
            URLSession.shared,
            task: URLSessionDataTask(),
            willPerformHTTPRedirection: HTTPURLResponse(),
            newRequest: redirectRequest,
            completionHandler: { request in
                XCTAssertEqual(request?.url, redirectURL)
                expectation.fulfill()
            })

        wait(for: [expectation], timeout: 1.0)
    }
    
    func testDidFinishDownloadingTo_Non2xxStatusCode_shouldIncludeResponseBody() {
        class MockDownloadTask: URLSessionDownloadTask, @unchecked Sendable {
            private let mockResponse: URLResponse?

            init(response: URLResponse?) {
                self.mockResponse = response
                super.init()
            }

            override var response: URLResponse? {
                return mockResponse
            }
        }
        
        let destinationURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let tempSourceURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        
        // Create a temporary file with error response body
        let errorResponseBody = "{\"error\": \"File not found\", \"code\": 404}"
        FileManager.default.createFile(atPath: tempSourceURL.path, contents: Data(errorResponseBody.utf8), attributes: nil)

        let mockResponse = HTTPURLResponse(
            url: destinationURL,
            statusCode: 404,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )
        let mockTask = MockDownloadTask(response: mockResponse)

        delegate.urlSession(URLSession.shared, downloadTask: mockTask, didFinishDownloadingTo: tempSourceURL)

        guard let exception = mockPublisher.failureCalled as? IONFLTRException,
              case .httpError(let responseCode, let responseBody, let headers) = exception else {
            XCTFail("Expected IONFLTRException.httpError")
            return
        }
        
        XCTAssertEqual(responseCode, 404)
        XCTAssertEqual(responseBody, errorResponseBody, "Response body should be included in HTTP error")
        XCTAssertEqual(headers?["Content-Type"], "application/json")
        
        // Verify the temporary file was cleaned up
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempSourceURL.path))
    }
    
    func testDidFinishDownloadingTo_Non2xxStatusCode_withInvalidUTF8_shouldHandleGracefully() {
        class MockDownloadTask: URLSessionDownloadTask, @unchecked Sendable {
            private let mockResponse: URLResponse?

            init(response: URLResponse?) {
                self.mockResponse = response
                super.init()
            }

            override var response: URLResponse? {
                return mockResponse
            }
        }
        
        let destinationURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let tempSourceURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        
        // Create a temporary file with invalid UTF-8 data
        let invalidUTF8Data = Data([0xFF, 0xFE, 0xFD])
        FileManager.default.createFile(atPath: tempSourceURL.path, contents: invalidUTF8Data, attributes: nil)

        let mockResponse = HTTPURLResponse(
            url: destinationURL,
            statusCode: 500,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/octet-stream"]
        )
        let mockTask = MockDownloadTask(response: mockResponse)

        delegate.urlSession(URLSession.shared, downloadTask: mockTask, didFinishDownloadingTo: tempSourceURL)

        guard let exception = mockPublisher.failureCalled as? IONFLTRException,
              case .httpError(let responseCode, let responseBody, let headers) = exception else {
            XCTFail("Expected IONFLTRException.httpError")
            return
        }
        
        XCTAssertEqual(responseCode, 500)
        XCTAssertNil(responseBody, "Response body should be nil when UTF-8 conversion fails")
        XCTAssertEqual(headers?["Content-Type"], "application/octet-stream")
    }
    
    func testDidCompleteWithError_Non2xxStatusCode_withoutReceivedData_shouldHaveNilResponseBody() {
        class MockURLSessionTask: URLSessionTask, @unchecked Sendable {
            private let mockResponse: URLResponse?
            
            init(response: URLResponse?) {
                self.mockResponse = response
            }
            
            override var response: URLResponse? {
                return mockResponse
            }
        }
        
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 404,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )
        let task = MockURLSessionTask(response: response)
        
        delegate.urlSession(URLSession.shared, task: task, didCompleteWithError: nil)
        
        guard let exception = mockPublisher.failureCalled as? IONFLTRException,
              case .httpError(let responseCode, let responseBody, let headers) = exception else {
            XCTFail("Expected IONFLTRException.httpError")
            return
        }
        
        XCTAssertEqual(responseCode, 404)
        XCTAssertNil(responseBody, "Response body should be nil when no data was received")
        XCTAssertEqual(headers?["Content-Type"], "application/json")
    }
    
    func testDidFinishDownloadingTo_Non2xxStatusCode_shouldPreventDuplicateErrorInDidCompleteWithError() {
        class MockDownloadTask: URLSessionDownloadTask, @unchecked Sendable {
            private let mockResponse: URLResponse?

            init(response: URLResponse?) {
                self.mockResponse = response
                super.init()
            }

            override var response: URLResponse? {
                return mockResponse
            }
        }
        
        let destinationURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let tempSourceURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        
        let errorResponseBody = "Error message"
        FileManager.default.createFile(atPath: tempSourceURL.path, contents: Data(errorResponseBody.utf8), attributes: nil)

        let mockResponse = HTTPURLResponse(
            url: destinationURL,
            statusCode: 403,
            httpVersion: nil,
            headerFields: nil
        )
        let mockTask = MockDownloadTask(response: mockResponse)

        // First call didFinishDownloadingTo which should handle the error
        delegate.urlSession(URLSession.shared, downloadTask: mockTask, didFinishDownloadingTo: tempSourceURL)
        
        // Verify error was sent
        XCTAssertNotNil(mockPublisher.failureCalled)
        let firstError = mockPublisher.failureCalled
        
        // Reset to track if another error is sent
        mockPublisher.failureCalled = nil
        
        // Then call didCompleteWithError - it should not send another error
        delegate.urlSession(URLSession.shared, task: mockTask, didCompleteWithError: nil)
        
        // Verify no duplicate error was sent
        XCTAssertNil(mockPublisher.failureCalled, "didCompleteWithError should not send duplicate error when errorHandled is true")
    }
    
    func testDidCompleteWithError_withoutError_shouldNotSendFailure() {        
        delegate.urlSession(URLSession.shared, task: URLSessionDataTask(), didCompleteWithError: nil)
        
        XCTAssertNil(mockPublisher.failureCalled)
    }
}
