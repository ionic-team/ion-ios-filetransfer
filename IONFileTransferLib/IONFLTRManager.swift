import Foundation

/// A manager class for handling file transfer operations.
///
/// The `IONFLTRManager` class provides methods to manage file downloads and uploads, including
/// preparing, validating, and executing file transfer operations. It integrates with validators,
/// file helpers, and URL request helpers to ensure smooth and reliable file transfers.
public class IONFLTRManager: NSObject {
    
    private let inputsValidator: IONFLTRInputsValidator
    private let fileHelper: IONFLTRFileHelper
    private let urlRequestHelper: IONFLTRURLRequestHelper
    private let transferRegistry: IONFLTRTransferRegistry
    
    /// Initializes a new instance of `IONFLTRManager`.
    ///
    /// - Parameters:
    ///   - inputsValidator: An instance of `IONFLTRInputsValidator` for validating inputs.
    ///   - fileHelper: An instance of `IONFLTRFileHelper` for file-related operations.
    ///   - urlRequestHelper: An instance of `IONFLTRURLRequestHelper` for configuring URL requests.
    ///   - transferRegistry: An instance of `IONFLTRTransferRegistry` for keeping track of the transfers in progress.
    init(
        inputsValidator: IONFLTRInputsValidator = .init(),
        fileHelper: IONFLTRFileHelper = .init(),
        urlRequestHelper: IONFLTRURLRequestHelper = .init(),
        transferRegistry: IONFLTRTransferRegistry = .init()
    ) {
        self.inputsValidator = inputsValidator
        self.fileHelper = fileHelper
        self.urlRequestHelper = urlRequestHelper
        self.transferRegistry = transferRegistry
    }
    
    override public init() {
        self.inputsValidator = IONFLTRInputsValidator()
        self.fileHelper = IONFLTRFileHelper()
        self.urlRequestHelper = IONFLTRURLRequestHelper()
        self.transferRegistry = IONFLTRTransferRegistry()
    }
    
    /// Downloads a file from the specified server URL to a local file URL.
    ///
    /// - Parameters:
    ///   - serverURL: The server `URL` from which the file will be downloaded.
    ///   - fileURL: The local file `URL` where the downloaded file will be saved.
    ///   - httpOptions: An instance of `IONFLTRHttpOptions` containing HTTP configuration options.
    ///   - transferId: The identifier used to abort the download through `abort(transferId:)`. If `nil`, one is
    ///     generated internally and the download can only be aborted through `abortAll()`.
    /// - Returns: An `IONFLTRPublisher` instance for tracking the download progress and completion.
    /// - Throws: An error if the download preparation or execution fails, including
    ///   `IONFLTRException.transferAlreadyInProgress` if `transferId` belongs to a transfer that is still in progress.
    public func downloadFile(
        fromServerURL serverURL: URL,
        toFileURL fileURL: URL,
        withHttpOptions httpOptions: IONFLTRHttpOptions,
        withTransferId transferId: String? = nil
    ) throws -> IONFLTRPublisher {
        do {
            let request = try prepareForDownload(serverURL: serverURL, fileURL: fileURL, httpOptions: httpOptions)
            let publisher = IONFLTRPublisher()
            let delegate = IONFLTRDownloadDelegate(
                publisher: publisher,
                destinationURL: fileURL,
                disableRedirects: httpOptions.disableRedirects
            )
            let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
            try start(
                session.downloadTask(with: request),
                on: session,
                publisher: publisher,
                transferId: transferId
            )
            return publisher
        } catch {
            throw mapErrorToIONFLTRException(error)
        }
    }
    
    /// Uploads a file from a local file URL to the specified server URL.
    ///
    /// - Parameters:
    ///   - fileURL: The local file `URL` to be uploaded.
    ///   - serverURL: The server `URL` to which the file will be uploaded.
    ///   - uploadOptions: An instance of `IONFLTRUploadOptions` containing upload-specific options.
    ///   - httpOptions: An instance of `IONFLTRHttpOptions` containing HTTP configuration options.
    ///   - transferId: The identifier used to abort the upload through `abort(transferId:)`. If `nil`, one is
    ///     generated internally and the upload can only be aborted through `abortAll()`.
    /// - Returns: An `IONFLTRPublisher` instance for tracking the upload progress and completion.
    /// - Throws: An error if the upload preparation or execution fails, including
    ///   `IONFLTRException.transferAlreadyInProgress` if `transferId` belongs to a transfer that is still in progress.
    public func uploadFile(
        fromFileURL fileURL: URL,
        toServerURL serverURL: URL,
        withUploadOptions uploadOptions: IONFLTRUploadOptions,
        andHttpOptions httpOptions: IONFLTRHttpOptions,
        withTransferId transferId: String? = nil
    ) throws -> IONFLTRPublisher {
        do {
            let (request, uploadFileURL) = try prepareForUpload(
                fileURL: fileURL,
                serverURL: serverURL,
                uploadOptions: uploadOptions,
                httpOptions: httpOptions
            )
            let publisher = IONFLTRPublisher()
            let delegate = IONFLTRUploadDelegate(
                publisher: publisher,
                disableRedirects: httpOptions.disableRedirects,
                fileURL: fileURL
            )
            let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
            let task = uploadOptions.chunkedMode
                ? session.uploadTask(withStreamedRequest: request)
                : session.uploadTask(with: request, fromFile: uploadFileURL)
            try start(task, on: session, publisher: publisher, transferId: transferId)
            return publisher
        } catch {
            throw mapErrorToIONFLTRException(error)
        }
    }
    
    /// Aborts the file transfer with the given identifier, if it is still in progress.
    ///
    /// The transfer's publisher completes with an `IONFLTRException.transferAborted` failure. Transfers that already
    /// completed - or that were started without a transfer identifier - are not affected.
    ///
    /// - Parameter transferId: The identifier of the transfer to abort.
    /// - Returns: `true` if the transfer was in progress and was aborted, `false` otherwise.
    @discardableResult
    public func abort(transferId: String) -> Bool {
        transferRegistry.abort(transferId)
    }
    
    /// Aborts every file transfer that is currently in progress.
    ///
    /// Each aborted transfer's publisher completes with an `IONFLTRException.transferAborted` failure.
    ///
    /// - Returns: The identifiers of the transfers that were aborted.
    @discardableResult
    public func abortAll() -> [String] {
        transferRegistry.abortAll()
    }
    
    /// The identifiers of the file transfers that are currently in progress.
    ///
    /// Transfers started without a transfer identifier are listed under the identifier generated for them.
    public var transferIdsInProgress: [String] {
        transferRegistry.transferIdsInProgress
    }
    
    /// Registers a transfer, so that it can be aborted, and starts it.
    ///
    /// - Parameters:
    ///   - task: The task running the transfer.
    ///   - session: The session the task belongs to.
    ///   - publisher: The publisher reporting the outcome of the transfer.
    ///   - transferId: The identifier to register the transfer under. A new one is generated when `nil`.
    /// - Throws: `IONFLTRException.transferAlreadyInProgress` if a transfer is already registered under `transferId`.
    private func start(
        _ task: URLSessionTask,
        on session: URLSession,
        publisher: IONFLTRPublisher,
        transferId: String?
    ) throws {
        let transferId = transferId ?? UUID().uuidString
        guard transferRegistry.register(
            transferId: transferId,
            session: session,
            task: task,
            publisher: publisher
        ) else {
            session.invalidateAndCancel()
            throw IONFLTRException.transferAlreadyInProgress(transferId: transferId)
        }
        task.resume()
    }
    
    /// Prepares for a file download operation by validating inputs and creating necessary directories.
    ///
    /// - Parameters:
    ///   - serverURL: The server `URL` from which the file will be downloaded.
    ///   - fileURL: The local file `URL` where the downloaded file will be saved.
    ///   - httpOptions: An instance of `IONFLTRHttpOptions` containing HTTP configuration options.
    /// - Returns: A configured `URLRequest` for the download operation.
    /// - Throws: An error if validation or directory creation fails.
    private func prepareForDownload(serverURL: URL, fileURL: URL, httpOptions: IONFLTRHttpOptions) throws -> URLRequest {
        let updatedFileURL = fileHelper.removeDuplicateSlashes(for: fileURL)
        try inputsValidator.validateTransferInputs(serverURL: serverURL, fileURL: updatedFileURL)
        try fileHelper.createParentDirectories(for: updatedFileURL)
        return try urlRequestHelper.setupRequest(serverURL: serverURL, httpOptions: httpOptions)
    }

    /// Prepares for a file upload operation by validating inputs and configuring the upload request.
    ///
    /// - Parameters:
    ///   - fileURL: The local file `URL` to be uploaded.
    ///   - serverURL: The server `URL` to which the file will be uploaded.
    ///   - uploadOptions: An instance of `IONFLTRUploadOptions` containing upload-specific options.
    ///   - httpOptions: An instance of `IONFLTRHttpOptions` containing HTTP configuration options.
    /// - Returns: A tuple containing the configured `URLRequest` and the file `URL` to be uploaded.
    /// - Throws: An error if validation or request configuration fails.
    private func prepareForUpload(
        fileURL: URL,
        serverURL: URL,
        uploadOptions: IONFLTRUploadOptions,
        httpOptions: IONFLTRHttpOptions
    ) throws -> (URLRequest, URL) {
        let updatedFileURL = fileHelper.removeDuplicateSlashes(for: fileURL)
        try inputsValidator.validateTransferInputs(serverURL: serverURL, fileURL: updatedFileURL)
        
        guard FileManager.default.fileExists(atPath: updatedFileURL.path) else {
            throw IONFLTRException.fileDoesNotExist(cause: nil)
        }
        
        let request = try urlRequestHelper.setupRequest(serverURL: serverURL, httpOptions: httpOptions)
        return try urlRequestHelper.configureRequestForUpload(
            request: request,
            httpOptions: httpOptions,
            uploadOptions: uploadOptions,
            fileURL: updatedFileURL,
            fileHelper: fileHelper
        )
    }
}
