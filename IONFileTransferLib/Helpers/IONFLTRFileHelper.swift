import Foundation
import UniformTypeIdentifiers

/// A helper class for file-related operations.
///
/// The `IONFLTRFileHelper` class provides utility methods for managing files, such as creating parent directories
/// and determining MIME types based on file extensions.
///
/// - Note: This class is used internally and is not intended for public use.
class IONFLTRFileHelper {
    
    /// Creates parent directories for a file if they don't exist.
    ///
    /// This method ensures that the directory structure required for a file is in place before performing
    /// file operations such as writing or moving files.
    ///
    /// - Parameter file: The file for which to create parent directories.
    /// - Throws: `IONFLTRException.cannotCreateDirectory` if the directories cannot be created.
    func createParentDirectories(for file: URL) throws {
        let parent = file.deletingLastPathComponent()
        var isDirectory: ObjCBool = false

        if !FileManager.default.fileExists(atPath: parent.path, isDirectory: &isDirectory) || !isDirectory.boolValue {
            do {
                try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true, attributes: nil)
            } catch {
                throw IONFLTRException.cannotCreateDirectory(path: parent.path, cause: error)
            }
        }
    }

    /// Gets a MIME type based on the provided file URL.
    ///
    /// This method uses the file extension to determine the MIME type of a file. If the MIME type cannot
    /// be determined, it returns `nil`.
    ///
    /// - Parameter url: The file URL.
    /// - Returns: The MIME type as a `String`, or `nil` if it cannot be determined.
    func mimeType(for url: URL) -> String? {
        return UTType(filenameExtension: url.pathExtension)?.preferredMIMEType
    }
}
