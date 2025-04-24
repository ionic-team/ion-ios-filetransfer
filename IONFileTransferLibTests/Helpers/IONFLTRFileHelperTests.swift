import XCTest
@testable import IONFileTransferLib

final class IONFLTRFileHelperTests: XCTestCase {

    var fileHelper: IONFLTRFileHelper!
    let fileManager = FileManager.default

    override func setUp() {
        super.setUp()
        fileHelper = IONFLTRFileHelper()
    }

    override func tearDown() {
        fileHelper = nil
        super.tearDown()
    }

    func testCreateParentDirectories_createsDirectoriesSuccessfully() throws {
        let tempDir = fileManager.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("testDir/subDir/testFile.txt")
        
        try fileHelper.createParentDirectories(for: testFile)
        
        var isDirectory: ObjCBool = false
        XCTAssertTrue(fileManager.fileExists(atPath: testFile.deletingLastPathComponent().path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
        
        // Cleanup
        try fileManager.removeItem(at: testFile.deletingLastPathComponent())
    }

    func testCreateParentDirectories_throwsErrorWhenCannotCreateDirectory() {
        let invalidPath = URL(fileURLWithPath: "/invalidPath/testFile.txt")
        
        XCTAssertThrowsError(try fileHelper.createParentDirectories(for: invalidPath)) { error in
            XCTAssertTrue(error is IONFLTRException)
        }
    }

    func testMimeType_returnsCorrectMimeType() {        
        let jpgURL = URL(fileURLWithPath: "file.jpg")
        let pdfURL = URL(fileURLWithPath: "file.pdf")
        let txtURL = URL(fileURLWithPath: "file.txt")

        XCTAssertEqual(fileHelper.mimeType(for: jpgURL), "image/jpeg")
        XCTAssertEqual(fileHelper.mimeType(for: pdfURL), "application/pdf")
        XCTAssertEqual(fileHelper.mimeType(for: txtURL), "text/plain")
    }

    func testMimeType_returnsNilForUnknownExtension() {
        let unknownURL = URL(fileURLWithPath: "file.unknownext")
        
        XCTAssertNil(fileHelper.mimeType(for: unknownURL))
    }
}
