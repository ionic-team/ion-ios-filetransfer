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

    /// Points to an address that never answers, so that transfers stay in progress until they are aborted.
    private let unreachableURL = URL(string: "https://10.255.255.1/file")!

    private func makeManager() -> IONFLTRManager {
        IONFLTRManager(
            inputsValidator: MockValidator(),
            fileHelper: MockFileHelper(),
            urlRequestHelper: MockRequestHelper()
        )
    }

    private func startDownload(on manager: IONFLTRManager, transferId: String? = nil) throws -> IONFLTRPublisher {
        try manager.downloadFile(
            fromServerURL: unreachableURL,
            toFileURL: FileManager.default.temporaryDirectory.appendingPathComponent("dummy.txt"),
            withHttpOptions: IONFLTRHttpOptions(method: "GET"),
            withTransferId: transferId
        )
    }

    func testDownloadFile_withTransferId_shouldTrackTransferAsInProgress() throws {
        let manager = makeManager()
        defer { manager.abortAll() }

        _ = try startDownload(on: manager, transferId: "download-1")

        XCTAssertEqual(manager.transferIdsInProgress, ["download-1"])
    }

    func testDownloadFile_withoutTransferId_shouldTrackTransferUnderGeneratedId() throws {
        let manager = makeManager()
        defer { manager.abortAll() }

        _ = try startDownload(on: manager)

        XCTAssertEqual(manager.transferIdsInProgress.count, 1)
        XCTAssertFalse(manager.transferIdsInProgress[0].isEmpty)
    }

    func testDownloadFile_withTransferIdAlreadyInProgress_shouldThrow() throws {
        let manager = makeManager()
        defer { manager.abortAll() }
        _ = try startDownload(on: manager, transferId: "download-1")

        XCTAssertThrowsError(try startDownload(on: manager, transferId: "download-1")) { error in
            XCTAssertEqual(
                error as? IONFLTRException,
                IONFLTRException.transferAlreadyInProgress(transferId: "download-1")
            )
        }
        XCTAssertEqual(manager.transferIdsInProgress, ["download-1"])
    }

    func testAbort_shouldStopTrackingTransfer() throws {
        let manager = makeManager()
        defer { manager.abortAll() }
        _ = try startDownload(on: manager, transferId: "download-1")

        XCTAssertTrue(manager.abort(transferId: "download-1"))
        XCTAssertTrue(manager.transferIdsInProgress.isEmpty)
    }

    func testAbort_withUnknownTransferId_shouldReturnFalse() throws {
        let manager = makeManager()
        defer { manager.abortAll() }
        _ = try startDownload(on: manager, transferId: "download-1")

        XCTAssertFalse(manager.abort(transferId: "download-2"))
        XCTAssertEqual(manager.transferIdsInProgress, ["download-1"])
    }

    func testAbortAll_shouldStopTrackingEveryTransfer() throws {
        let manager = makeManager()
        defer { manager.abortAll() }
        _ = try startDownload(on: manager, transferId: "download-1")
        _ = try startDownload(on: manager, transferId: "download-2")

        XCTAssertEqual(manager.abortAll().sorted(), ["download-1", "download-2"])
        XCTAssertTrue(manager.transferIdsInProgress.isEmpty)
    }

    func testUploadFile_withTransferId_shouldTrackTransferAsInProgress() throws {
        let manager = makeManager()
        defer { manager.abortAll() }

        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("testAbortUpload.txt")
        FileManager.default.createFile(atPath: fileURL.path, contents: Data("test".utf8), attributes: nil)

        _ = try manager.uploadFile(
            fromFileURL: fileURL,
            toServerURL: unreachableURL,
            withUploadOptions: IONFLTRUploadOptions(
                chunkedMode: false,
                mimeType: nil,
                fileKey: "file",
                formParams: [:]
            ),
            andHttpOptions: IONFLTRHttpOptions(method: "POST", headers: [:], disableRedirects: false),
            withTransferId: "upload-1"
        )

        XCTAssertEqual(manager.transferIdsInProgress, ["upload-1"])
        XCTAssertTrue(manager.abort(transferId: "upload-1"))
    }
}
