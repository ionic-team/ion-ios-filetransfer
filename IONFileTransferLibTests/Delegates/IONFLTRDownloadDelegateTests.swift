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
        let request = URLRequest(url: URL(string: "https://example.com/file")!)
        
        delegate.urlSession(
            URLSession.shared,
            downloadTask: URLSession(configuration: .default).downloadTask(with: request),
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
    
    func testDidCompleteWithError_Non2xxStatusCode() {
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
        
        XCTAssertEqual(
            mockPublisher.failureCalled as? IONFLTRException?,
            IONFLTRException.httpError(responseCode: 404, responseBody: nil, headers: ["Content-Type": "application/json"])
        )
    }
    
    func testDidCompleteWithError_withoutError_shouldNotSendFailure() {        
        delegate.urlSession(URLSession.shared, task: URLSessionDataTask(), didCompleteWithError: nil)
        
        XCTAssertNil(mockPublisher.failureCalled)
    }
}
