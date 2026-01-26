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
            disableRedirects: false,
            fileURL: URL(string: "somefile_path/not_relevat_for_test.txt")!
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
            disableRedirects: true,
            fileURL: URL(string: "somefile_path/not_relevat_for_test.txt")!
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

    func testDidReceiveData_shouldAccumulateData() {
        let data1 = "Part1".data(using: .utf8)!
        let data2 = "Part2".data(using: .utf8)!
        
        let task = URLSession.shared.dataTask(with: URL(string: "https://example.com")!)

        delegate.urlSession(URLSession.shared, dataTask: task, didReceive: data1)
        delegate.urlSession(URLSession.shared, dataTask: task, didReceive: data2)

        let response = HTTPURLResponse(
            url: task.originalRequest!.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "text/plain"]
        )
        
        class MockTask: URLSessionTask, @unchecked Sendable {
            let mockResponse: URLResponse?
            override var response: URLResponse? { return mockResponse }
            init(response: URLResponse?) { self.mockResponse = response }
        }

        let mockTask = MockTask(response: response)
        delegate.urlSession(URLSession.shared, task: mockTask, didCompleteWithError: nil)

        let result = mockPublisher.successCalled
        XCTAssertEqual(result?.2, "Part1Part2")
        XCTAssertEqual(result?.3["Content-Type"], "text/plain")
    }

    
    func testDidCompleteWithError_Non2xxStatusCode_shouldIncludeResponseBody() {
        class MockURLSessionTask: URLSessionTask, @unchecked Sendable {
            private let mockResponse: URLResponse?
            
            init(response: URLResponse?) {
                self.mockResponse = response
            }
            
            override var response: URLResponse? {
                return mockResponse
            }
        }
        
        let errorResponseBody = "{\"error\": \"Resource not found\", \"status\": 404}"
        let errorData = errorResponseBody.data(using: .utf8)!
        
        // Simulate receiving response data before error
        let task = URLSession.shared.dataTask(with: URL(string: "https://example.com")!)
        delegate.urlSession(URLSession.shared, dataTask: task, didReceive: errorData)
        
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 404,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )
        let mockTask = MockURLSessionTask(response: response)
        
        delegate.urlSession(URLSession.shared, task: mockTask, didCompleteWithError: nil)
        
        guard let exception = mockPublisher.failureCalled as? IONFLTRException,
              case .httpError(let responseCode, let responseBody, let headers) = exception else {
            XCTFail("Expected IONFLTRException.httpError")
            return
        }
        
        XCTAssertEqual(responseCode, 404)
        XCTAssertEqual(responseBody, errorResponseBody, "Response body should be included in HTTP error")
        XCTAssertEqual(headers?["Content-Type"], "application/json")
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
            statusCode: 500,
            httpVersion: nil,
            headerFields: ["Content-Type": "text/plain"]
        )
        let task = MockURLSessionTask(response: response)
        
        // Don't receive any data before the error
        delegate.urlSession(URLSession.shared, task: task, didCompleteWithError: nil)
        
        guard let exception = mockPublisher.failureCalled as? IONFLTRException,
              case .httpError(let responseCode, let responseBody, let headers) = exception else {
            XCTFail("Expected IONFLTRException.httpError")
            return
        }
        
        XCTAssertEqual(responseCode, 500)
        XCTAssertNil(responseBody, "Response body should be nil when no data was received")
        XCTAssertEqual(headers?["Content-Type"], "text/plain")
    }
    
    func testDidCompleteWithSuccess_shouldSendSuccess() {
        let responseBody = "Uploaded!"
        let data = responseBody.data(using: .utf8)!
        
        let task = URLSession.shared.dataTask(with: URL(string: "https://example.com")!)
        delegate.urlSession(URLSession.shared, dataTask: task, didReceive: data)

        class MockTask: URLSessionTask {
            let mockResponse: URLResponse?
            override var response: URLResponse? { return mockResponse }
            init(response: URLResponse?) { self.mockResponse = response }
        }

        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 201,
            httpVersion: nil,
            headerFields: ["X-Custom": "value"]
        )
        let mockTask = MockTask(response: mockResponse)

        delegate.urlSession(URLSession.shared, task: mockTask, didCompleteWithError: nil)

        XCTAssertEqual(mockPublisher.successCalled?.0, 0) // totalBytesSent is default 0
        XCTAssertEqual(mockPublisher.successCalled?.1, 201)
        XCTAssertEqual(mockPublisher.successCalled?.2, responseBody)
        XCTAssertEqual(mockPublisher.successCalled?.3["X-Custom"], "value")
    }
    
    func testBodyStream_retrievedFromTestFile() {
        let testFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("testFile.txt")
        try? "Test content".write(to: testFileURL, atomically: true, encoding: .utf8)
        delegate = IONFLTRUploadDelegate(
            publisher: mockPublisher,
            disableRedirects: true,
            fileURL: testFileURL
        )
        let expectation = self.expectation(description: "stream is correct")

        let task = URLSession.shared.dataTask(with: URL(string: "https://example.com")!)
        delegate.urlSession(
            URLSession.shared,
            task: task,
            needNewBodyStream: { stream in
                XCTAssertNotNil(stream)
                stream?.open()
                var buffer = [UInt8](repeating: 0, count: 100)
                let bytesRead = stream!.read(&buffer, maxLength: buffer.count)
                XCTAssertGreaterThan(bytesRead, 0)
                let outputString = String(bytes: buffer[0..<bytesRead], encoding: .utf8)
                XCTAssertEqual(outputString, "Test content")
                stream?.close()
                expectation.fulfill()
            }
        )
        waitForExpectations(timeout: 1)
    }
}
