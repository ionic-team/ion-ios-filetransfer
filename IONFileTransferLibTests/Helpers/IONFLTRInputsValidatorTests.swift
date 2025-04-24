import XCTest
@testable import IONFileTransferLib

final class IONFLTRInputsValidatorTests: XCTestCase {
    
    var validator: IONFLTRInputsValidator!
    
    override func setUp() {
        super.setUp()
        validator = IONFLTRInputsValidator()
    }

    override func tearDown() {
        validator = nil
        super.tearDown()
    }

    func testValidateTransferInputs_withValidHTTPAndFileURL_shouldNotThrow() {
        let serverURL = URL(string: "https://example.com")!
        let fileURL = URL(fileURLWithPath: "/tmp/testfile.txt")
        
        XCTAssertNoThrow(try validator.validateTransferInputs(serverURL: serverURL, fileURL: fileURL))
    }

    func testValidateTransferInputs_withEmptyServerURL_shouldThrowEmptyURLException() {
        let serverURL = URL(string: "   ".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)!
        let fileURL = URL(fileURLWithPath: "/tmp/testfile.txt")

        XCTAssertThrowsError(try validator.validateTransferInputs(serverURL: serverURL, fileURL: fileURL)) { error in
            guard let err = error as? IONFLTRException else {
                return XCTFail("Erro inesperado: \(error)")
            }
            XCTAssertEqual(err, .emptyURL(url: serverURL.absoluteString))
        }
    }

    func testValidateTransferInputs_withInvalidScheme_shouldThrowInvalidURLException() {
        let serverURL = URL(string: "ftp://example.com")!
        let fileURL = URL(fileURLWithPath: "/tmp/testfile.txt")

        XCTAssertThrowsError(try validator.validateTransferInputs(serverURL: serverURL, fileURL: fileURL)) { error in
            guard let err = error as? IONFLTRException else {
                return XCTFail("Erro inesperado: \(error)")
            }
            XCTAssertEqual(err, .invalidURL(url: serverURL.absoluteString))
        }
    }

    func testValidateTransferInputs_withMissingHost_shouldThrowInvalidURLException() {
        let serverURL = URL(string: "https://")!
        let fileURL = URL(fileURLWithPath: "/tmp/testfile.txt")

        XCTAssertThrowsError(try validator.validateTransferInputs(serverURL: serverURL, fileURL: fileURL)) { error in
            guard let err = error as? IONFLTRException else {
                return XCTFail("Erro inesperado: \(error)")
            }
            XCTAssertEqual(err, .invalidURL(url: serverURL.absoluteString))
        }
    }

    func testValidateTransferInputs_withNonFileURL_shouldThrowInvalidPathException() {
        let serverURL = URL(string: "https://example.com")!
        let fileURL = URL(string: "https://not-a-file.com")!

        XCTAssertThrowsError(try validator.validateTransferInputs(serverURL: serverURL, fileURL: fileURL)) { error in
            guard let err = error as? IONFLTRException else {
                return XCTFail("Erro inesperado: \(error)")
            }
            XCTAssertEqual(err, .invalidPath(path: fileURL.path))
        }
    }
}
