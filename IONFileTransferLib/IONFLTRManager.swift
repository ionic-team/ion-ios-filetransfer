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
    
    /// Initializes a new instance of `IONFLTRManager`.
    ///
    /// - Parameters:
    ///   - inputsValidator: An instance of `IONFLTRInputsValidator` for validating inputs.
    ///   - fileHelper: An instance of `IONFLTRFileHelper` for file-related operations.
    ///   - urlRequestHelper: An instance of `IONFLTRURLRequestHelper` for configuring URL requests.
    init(
        inputsValidator: IONFLTRInputsValidator = .init(),
        fileHelper: IONFLTRFileHelper = .init(),
        urlRequestHelper: IONFLTRURLRequestHelper = .init()
    ) {
        self.inputsValidator = inputsValidator
        self.fileHelper = fileHelper
        self.urlRequestHelper = urlRequestHelper
    }
    
    override public init() {
        self.inputsValidator = IONFLTRInputsValidator()
        self.fileHelper = IONFLTRFileHelper()
        self.urlRequestHelper = IONFLTRURLRequestHelper()
    }
    
    /// Downloads a file from the specified server URL to a local file URL.
    ///
    /// - Parameters:
    ///   - serverURL: The server `URL` from which the file will be downloaded.
    ///   - fileURL: The local file `URL` where the downloaded file will be saved.
    ///   - httpOptions: An instance of `IONFLTRHttpOptions` containing HTTP configuration options.
    /// - Returns: An `IONFLTRPublisher` instance for tracking the download progress and completion.
    /// - Throws: An error if the download preparation or execution fails.
    public func downloadFile(
        fromServerURL serverURL: URL,
        toFileURL fileURL: URL,
        withHttpOptions httpOptions: IONFLTRHttpOptions
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
            session.downloadTask(with: request).resume()
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
    /// - Returns: An `IONFLTRPublisher` instance for tracking the upload progress and completion.
    /// - Throws: An error if the upload preparation or execution fails.
    public func uploadFile(
        fromFileURL fileURL: URL,
        toServerURL serverURL: URL,
        withUploadOptions uploadOptions: IONFLTRUploadOptions,
        andHttpOptions httpOptions: IONFLTRHttpOptions
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
                disableRedirects: httpOptions.disableRedirects
            )
            let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
            if uploadOptions.chunkedMode {
                session.uploadTask(withStreamedRequest: request).resume()
            } else {
                session.uploadTask(with: request, fromFile: uploadFileURL).resume()
            }
            return publisher
        } catch {
            throw mapErrorToIONFLTRException(error)
        }
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
        try inputsValidator.validateTransferInputs(serverURL: serverURL, fileURL: fileURL)
        try fileHelper.createParentDirectories(for: fileURL)
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
        try inputsValidator.validateTransferInputs(serverURL: serverURL, fileURL: fileURL)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw IONFLTRException.fileDoesNotExist(cause: nil)
        }
        
        let request = try urlRequestHelper.setupRequest(serverURL: serverURL, httpOptions: httpOptions)
        return try urlRequestHelper.configureRequestForUpload(
            request: request,
            httpOptions: httpOptions,
            uploadOptions: uploadOptions,
            fileURL: fileURL,
            fileHelper: fileHelper
        )
    }
}
