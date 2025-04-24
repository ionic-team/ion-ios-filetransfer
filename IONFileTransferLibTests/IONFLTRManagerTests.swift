import XCTest
@testable import IONFileTransferLib

final class IONFLTRManagerTests: XCTestCase {
    
    class MockValidator: IONFLTRInputsValidator {
        var didCallValidate = false
        override func validateTransferInputs(serverURL: URL, fileURL: URL) throws {
            didCallValidate = true
        }
    }

    class MockFileHelper: IONFLTRFileHelper {
        var didCallCreateParentDirectories = false
        override func createParentDirectories(for fileURL: URL) throws {
            didCallCreateParentDirectories = true
        }

        override func mimeType(for fileURL: URL) -> String? {
            return "plain/text"
        }
    }

    class MockRequestHelper: IONFLTRURLRequestHelper {
        var didCallSetupRequest = false
        override func setupRequest(serverURL: URL, httpOptions: IONFLTRHttpOptions) throws -> URLRequest {
            didCallSetupRequest = true
            return URLRequest(url: serverURL)
        }
    }

    func testDownloadFile_shouldCreateRequestAndReturnPublisher() async throws {
        let validator = MockValidator()
        let fileHelper = MockFileHelper()
        let requestHelper = MockRequestHelper()

        let manager = IONFLTRManager(
            inputsValidator: validator,
            fileHelper: fileHelper,
            urlRequestHelper: requestHelper
        )

        let serverURL = URL(string: "https://example.com/file")!
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("dummy.txt")

        let httpOptions = IONFLTRHttpOptions(method: "GET")

        let publisher = try await manager.downloadFile(
            fromServerURL: serverURL,
            toFileURL: fileURL,
            withHttpOptions: httpOptions
        )

        XCTAssertTrue(validator.didCallValidate)
        XCTAssertTrue(fileHelper.didCallCreateParentDirectories)
        XCTAssertTrue(requestHelper.didCallSetupRequest)
        XCTAssertNotNil(publisher)
    }

    func testUploadFile_shouldCreateMultipartOrChunkedRequest() async throws {
        let validator = MockValidator()
        let fileHelper = MockFileHelper()
        let requestHelper = MockRequestHelper()

        let manager = IONFLTRManager(
            inputsValidator: validator,
            fileHelper: fileHelper,
            urlRequestHelper: requestHelper
        )

        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("testUpload.txt")
        let serverURL = URL(string: "https://example.com/upload")!

        FileManager.default.createFile(atPath: fileURL.path, contents: Data("test".utf8), attributes: nil)

        let uploadOptions = IONFLTRUploadOptions(
            chunkedMode: false,
            mimeType: nil,
            fileKey: "file",
            formParams: ["param1": "value1"]
        )

        let httpOptions = IONFLTRHttpOptions(method: "POST", headers: [:], disableRedirects: false)

        let publisher = try await manager.uploadFile(
            fromFileURL: fileURL,
            toServerURL: serverURL,
            withUploadOptions: uploadOptions,
            andHttpOptions: httpOptions
        )

        XCTAssertTrue(validator.didCallValidate)
        XCTAssertTrue(requestHelper.didCallSetupRequest)
        XCTAssertNotNil(publisher)
    }
}
