import XCTest
@testable import IONFileTransferLib

class IONFLTRURLRequestHelperTests: XCTestCase {

    var requestHelper: IONFLTRURLRequestHelper!
    var fileHelper: IONFLTRFileHelper!
    var mockHttpOptions: IONFLTRHttpOptions!
    var serverURL: URL!
    var testFileURL: URL!

    override func setUp() {
        super.setUp()
        requestHelper = IONFLTRURLRequestHelper()
        fileHelper = IONFLTRFileHelper()
        mockHttpOptions = IONFLTRHttpOptions(
            method: "GET",
            params: ["key": ["value"]],
            headers: ["Content-Type": "application/json"],
            timeout: 5,
            shouldEncodeUrlParams: true
        )
        serverURL = URL(string: "https://example.com")!
        testFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("testFile.txt")
        try? "Test content".write(to: testFileURL, atomically: true, encoding: .utf8)
    }

    override func tearDown() {
        requestHelper = nil
        mockHttpOptions = nil
        super.tearDown()
    }

    func testSetupRequest_withValidGETRequest() throws {
        let request = try requestHelper.setupRequest(serverURL: serverURL, httpOptions: mockHttpOptions)

        XCTAssertEqual(request.url?.absoluteString, "https://example.com?key=value")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.timeoutInterval, 5.0)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertNil(request.httpBody)
    }

    func testSetupRequest_withPOSTRequestAndBody() throws {
        mockHttpOptions.method = "POST"
        let serverURL = URL(string: "https://example.com")!
        let request = try requestHelper.setupRequest(serverURL: serverURL, httpOptions: mockHttpOptions)

        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertNotNil(request.httpBody)
        XCTAssertEqual(String(data: request.httpBody!, encoding: .utf8), "key=value")
    }

    func testSetupRequest_withQueryItems() throws {
        mockHttpOptions.params = [
            "key1": ["value with spaces"],
            "key2": ["another value"],
            "key3": ["special&chars"]
        ]
        let request = try requestHelper.setupRequest(serverURL: serverURL, httpOptions: mockHttpOptions)

        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertNotNil(request.url)
        XCTAssertTrue(
            [
                "https://example.com?key1=value%20with%20spaces&key2=another%20value&key3=special%26chars",
                "https://example.com?key1=value%20with%20spaces&key3=special%26chars&key2=another%20value",
                "https://example.com?key2=another%20value&key1=value%20with%20spaces&key3=special%26chars",
                "https://example.com?key2=another%20value&key3=special%26chars&key1=value%20with%20spaces",
                "https://example.com?key3=special%26chars&key1=value%20with%20spaces&key2=another%20value",
                "https://example.com?key3=special%26chars&key2=another%20value&key1=value%20with%20spaces"
            ].contains(request.url?.absoluteString ?? "")
        )
        XCTAssertNil(request.httpBody)
    }

    func testSetupRequest_withEmptyParams() throws {
        mockHttpOptions.params = [:]
        let request = try requestHelper.setupRequest(serverURL: serverURL, httpOptions: mockHttpOptions)

        XCTAssertEqual(request.url?.absoluteString, "https://example.com")
        XCTAssertNil(request.httpBody)
    }

    func testSetupRequest_generatesCorrectHttpBody_withEncodedParams() throws {
        mockHttpOptions.method = "POST"
        mockHttpOptions.params = ["key1": ["value1"], "key2": ["value with spaces"]]

        let request = try requestHelper.setupRequest(serverURL: serverURL, httpOptions: mockHttpOptions)

        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertNotNil(request.url)
        XCTAssertEqual(serverURL.absoluteString, request.url!.absoluteString)
        XCTAssertNotNil(request.httpBody)
        XCTAssertTrue(
            ["key1=value1&key2=value%20with%20spaces", "key2=value%20with%20spaces&key1=value1"].contains(
                String(data: request.httpBody!, encoding: .utf8)
            )
        )
    }
    
    func testSetupRequest_generatesCorrectHttpBody_withoutEncodedParams() throws {
        mockHttpOptions.method = "POST"
        mockHttpOptions.params = ["key1": ["value1"], "key2": ["value with spaces"]]
        mockHttpOptions.shouldEncodeUrlParams = false

        let request = try requestHelper.setupRequest(serverURL: serverURL, httpOptions: mockHttpOptions)

        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertNotNil(request.url)
        XCTAssertEqual(serverURL.absoluteString, request.url!.absoluteString)
        XCTAssertNotNil(request.httpBody)
        XCTAssertTrue(
            ["key1=value1&key2=value with spaces", "key2=value with spaces&key1=value1"].contains(
                String(data: request.httpBody!, encoding: .utf8)
            )
        )
    }
    
    func testConfigureRequestForUpload_withChunkedMode() throws {
        let uploadOptions = IONFLTRUploadOptions(
            chunkedMode: true,
            mimeType: nil,
            fileKey: "file",
            formParams: nil
        )
        let request = try requestHelper.setupRequest(serverURL: serverURL, httpOptions: mockHttpOptions)

        let (configuredRequest, fileURL) = try requestHelper.configureRequestForUpload(
            request: request,
            httpOptions: mockHttpOptions,
            uploadOptions: uploadOptions,
            fileURL: testFileURL,
            fileHelper: fileHelper
        )
        
        let fileData = try Data(contentsOf: testFileURL)
        XCTAssertEqual(fileURL, testFileURL)
        XCTAssertNil(configuredRequest.httpBodyStream)
        XCTAssertEqual(configuredRequest.value(forHTTPHeaderField: "Content-Length"), String(fileData.count))
    }
    
    func testConfigureRequestForUpload_withMultipartUpload() throws {
        mockHttpOptions.method = "POST"
        mockHttpOptions.headers.removeValue(forKey: "Content-Type")
        let uploadOptions = IONFLTRUploadOptions(
            chunkedMode: false,
            mimeType: "text/plain",
            fileKey: "file",
            formParams: ["key1": "value1"]
        )
        let request = try requestHelper.setupRequest(serverURL: serverURL, httpOptions: mockHttpOptions)

        let (configuredRequest, tempFileURL) = try requestHelper.configureRequestForUpload(
            request: request,
            httpOptions: mockHttpOptions,
            uploadOptions: uploadOptions,
            fileURL: testFileURL,
            fileHelper: fileHelper
        )

        let fileData = try Data(contentsOf: testFileURL)
        XCTAssertEqual(configuredRequest.value(forHTTPHeaderField: "Content-Type")?.contains("multipart/form-data"), true)
        XCTAssertTrue(Int(configuredRequest.value(forHTTPHeaderField: "Content-Length")!)! > fileData.count)
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempFileURL.path))
        try? FileManager.default.removeItem(at: tempFileURL)
    }

    func testCreateMultipartBody() throws {
        let uploadOptions = IONFLTRUploadOptions(
            chunkedMode: false,
            mimeType: "text/plain",
            fileKey: "file",
            formParams: ["key1": "value1"]
        )

        let boundary = "++++IONFLTRBoundary"
        let body = try requestHelper.createMultipartBody(
            uploadOptions: uploadOptions,
            fileURL: testFileURL,
            fileHelper: fileHelper,
            boundary: boundary
        )

        let expectedBody = """
        --++++IONFLTRBoundary\r
        Content-Disposition: form-data; name="key1"\r
        \r
        value1\r
        --++++IONFLTRBoundary\r
        Content-Disposition: form-data; name="file"; filename="testFile.txt"\r
        Content-Type: text/plain\r
        \r
        Test content\r
        --++++IONFLTRBoundary--\r
        
        """

        let bodyString = String(data: body, encoding: .utf8)
        XCTAssertEqual(bodyString, expectedBody)
    }
}
