/// Represents upload-specific configuration options for file transfer operations.
///
/// The `IONFLTRUploadOptions` struct provides a way to configure settings specific to file uploads,
/// such as enabling chunked mode, specifying the MIME type, and including additional form parameters.
public struct IONFLTRUploadOptions {
    
    /// Creates a new instance of `IONFLTRUploadOptions` with the specified configuration.
    ///
    /// - Parameters:
    ///   - chunkedMode: A flag indicating whether the upload should use chunked mode. Defaults to `false`.
    ///   - mimeType: The MIME type of the file being uploaded. Defaults to `nil`.
    ///   - fileKey: The key used to identify the file in the form data. Defaults to `"file"`.
    ///   - formParams: Additional form parameters to include with the upload request. Defaults to `nil`.
    public init(
        chunkedMode: Bool = false,
        mimeType: String? = nil,
        fileKey: String = "file",
        formParams: [String: String]? = nil
    ) {
        self.chunkedMode = chunkedMode
        self.mimeType = mimeType
        self.fileKey = fileKey
        self.formParams = formParams
    }
    
    /// A flag indicating whether the upload should use chunked mode.
    ///
    /// Defaults to `false`.
    var chunkedMode: Bool

    /// The MIME type of the file being uploaded.
    ///
    /// Defaults to `nil`.
    var mimeType: String?

    /// The key used to identify the file in the form data.
    ///
    /// Default value is `"file"`.
    var fileKey: String

    /// Additional form parameters to include with the upload request.
    ///
    /// Defaults to `nil`.
    var formParams: [String: String]?
}
