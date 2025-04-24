import XCTest
@testable import IONFileTransferLib

final class IONFLTRUploadDelegateTests: XCTestCase {

    class MockPublisher: IONFLTRPublisher {
        var progressCalled: (Int, Int)?
        var successCalled: (Int, Int, String?, [String: String])?
        var failureCalled: Error?

        override func sendProgress(_ totalBytesSent: Int, totalBytesExpected totalBytesExpectedToSend: Int) {
            progressCalled = (totalBytesSent, totalBytesExpectedToSend)
        }

        override func sendSuccess(totalBytes: Int, responseCode: Int, responseBody: String?, headers: [String : String]) {
            successCalled = (totalBytes, responseCode, responseBody, headers)
        }
        
        override func sendFailure(_ error: any Error) {
            failureCalled = error
        }
    }

    var mockPublisher: MockPublisher!
    var delegate: IONFLTRUploadDelegate!

    override func setUp() {
        super.setUp()
        mockPublisher = MockPublisher()
        delegate = IONFLTRUploadDelegate(
            publisher: mockPublisher,
            disableRedirects: false
        )
    }

    func testDidSendBodyData_shouldCallSendProgress() {
        let task = URLSession.shared.dataTask(with: URL(string: "https://example.com")!)

        delegate.urlSession(
            URLSession.shared,
            task: task,
            didSendBodyData: 100,
            totalBytesSent: 500,
            totalBytesExpectedToSend: 1000
        )

        XCTAssertEqual(mockPublisher.progressCalled?.0, 500)
        XCTAssertEqual(mockPublisher.progressCalled?.1, 1000)
    }

    func testDidCompleteWithError_shouldCallErrorHandler() {
        let task = URLSession.shared.dataTask(with: URL(string: "https://example.com")!)
        let simulatedError = NSError(domain: "Test", code: 123, userInfo: nil)

        delegate.urlSession(URLSession.shared, task: task, didCompleteWithError: simulatedError)

        XCTAssertNotNil(mockPublisher.failureCalled)
        XCTAssertEqual(mockPublisher.failureCalled as NSError?, simulatedError)
    }

    func testRedirection_shouldFollowByDefault() {
        let task = URLSession.shared.dataTask(with: URL(string: "https://example.com")!)
        let response = HTTPURLResponse(url: task.originalRequest!.url!, statusCode: 302, httpVersion: nil, headerFields: nil)!
        let newRequest = URLRequest(url: URL(string: "https://example.com/redirected")!)

        let expectation = self.expectation(description: "Redirection handler called")

        delegate.urlSession(URLSession.shared, task: task, willPerformHTTPRedirection: response, newRequest: newRequest) { redirectedRequest in
            XCTAssertEqual(redirectedRequest?.url?.absoluteString, "https://example.com/redirected")
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1)
    }

    func testRedirection_shouldBeCancelledWhenDisabled() {
        delegate = IONFLTRUploadDelegate(
            publisher: mockPublisher,
            disableRedirects: true
        )

        let task = URLSession.shared.dataTask(with: URL(string: "https://example.com")!)
        let response = HTTPURLResponse(url: task.originalRequest!.url!, statusCode: 302, httpVersion: nil, headerFields: nil)!
        let newRequest = URLRequest(url: URL(string: "https://example.com/redirected")!)

        let expectation = self.expectation(description: "Redirection handler called")

        delegate.urlSession(URLSession.shared, task: task, willPerformHTTPRedirection: response, newRequest: newRequest) { redirectedRequest in
            XCTAssertNil(redirectedRequest)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1)
    }

    func testDidReceiveData_shouldCallSendSuccess() {
        class MockDataTask: URLSessionDataTask, @unchecked Sendable {
            private let mockResponse: URLResponse?

            override var response: URLResponse? {
                return mockResponse
            }

            init(response: URLResponse?) {
                self.mockResponse = response
                super.init()
            }
        }
        
        let expectedResponseBody = "Success!"
        let data = expectedResponseBody.data(using: .utf8)!
        let task = URLSession.shared.dataTask(with: URL(string: "https://example.com")!)

        let urlResponse = HTTPURLResponse(url: task.originalRequest!.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "text/plain"])
        let dataTask = MockDataTask(response: urlResponse)

        delegate.urlSession(URLSession.shared, dataTask: dataTask, didReceive: data)

        let result = mockPublisher.successCalled
        XCTAssertEqual(result?.0, 0) // totalBytesSent should still be 0
        XCTAssertEqual(result?.1, 200)
        XCTAssertEqual(result?.2, expectedResponseBody)
        XCTAssertEqual(result?.3["Content-Type"], "text/plain")
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
