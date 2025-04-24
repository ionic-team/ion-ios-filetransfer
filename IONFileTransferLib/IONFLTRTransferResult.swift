/// Represents the result of a file transfer operation.
///
/// The `IONFLTRTransferResult` enum encapsulates the state of a file transfer operation,
/// including ongoing progress updates and the final completion result.
public enum IONFLTRTransferResult: Equatable {
    /// Indicates that the file transfer is ongoing.
    ///
    /// - Parameter status: An instance of `IONFLTRProgressStatus` containing progress details.
    case ongoing(status: IONFLTRProgressStatus)

    /// Indicates that the file transfer has completed successfully.
    ///
    /// - Parameter data: An instance of `IONFLTRTransferComplete` containing the completion details.
    case complete(data: IONFLTRTransferComplete)
}

/// Represents the progress status of a file transfer operation.
///
/// The `IONFLTRProgressStatus` struct provides details about the current progress of a file transfer,
/// including the number of bytes transferred and whether the total content length is computable.
public struct IONFLTRProgressStatus: Equatable {
    /// The number of bytes transferred so far.
    public var bytes: Int

    /// The total number of bytes expected to be transferred.
    public var contentLength: Int

    /// A flag indicating whether the total content length is computable.
    public var lengthComputable: Bool
}

/// Represents the completion details of a file transfer operation.
///
/// The `IONFLTRTransferComplete` struct provides information about the result of a completed file transfer,
/// including the total bytes transferred, the server's response code, and any response headers or body.
public struct IONFLTRTransferComplete: Equatable {
    /// The total number of bytes transferred during the operation.
    public var totalBytes: Int

    /// The HTTP response code returned by the server.
    public var responseCode: Int

    /// The response body returned by the server, if available.
    public var responseBody: String? = nil

    /// The HTTP headers returned by the server.
    public var headers: [String: String] = [:]
}
