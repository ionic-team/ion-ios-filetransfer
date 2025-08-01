import Foundation

/// A helper class for configuring and creating URL requests for file uploads and downloads.
///
/// The `IONFLTRURLRequestHelper` class provides methods to set up and configure `URLRequest` objects
/// for various HTTP operations, including handling query parameters, HTTP headers, and multipart form data.
///
/// - Note: This class is used internally and is not intended for public use.
class IONFLTRURLRequestHelper {
    
    /// Configures a URL request for file download and upload.
    ///
    /// - Parameters:
    ///   - serverURL: The base URL of the server.
    ///   - httpOptions: The HTTP options containing method, headers, and other configurations.
    /// - Returns: A configured `URLRequest` object.
    /// - Throws: `IONFLTRException.invalidURL` if the URL is invalid.
    func setupRequest(serverURL: URL, httpOptions: IONFLTRHttpOptions) throws -> URLRequest {
        guard var urlComponents = URLComponents(url: serverURL, resolvingAgainstBaseURL: false) else {
            throw IONFLTRException.invalidURL(url: serverURL.absoluteString)
        }
        
        if httpOptions.method.uppercased() == "GET", !httpOptions.params.isEmpty {
            urlComponents.queryItems = buildQueryItems(from: httpOptions)
        }
        
        guard let url = urlComponents.url else {
            throw IONFLTRException.invalidURL(url: serverURL.absoluteString)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = httpOptions.method
        request.timeoutInterval = TimeInterval(httpOptions.timeout)
        
        for (key, value) in httpOptions.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        if httpOptions.method.uppercased() != "GET", !httpOptions.params.isEmpty {
            request.httpBody = buildHttpBody(from: httpOptions)
        }
        
        return request
    }
    
    /// Configures a URL request for file upload.
    ///
    /// - Parameters:
    ///   - request: The original `URLRequest` to be configured.
    ///   - httpOptions: The HTTP options containing method, headers, and other configurations.
    ///   - uploadOptions: The upload options specifying chunked mode, MIME type, and form parameters.
    ///   - fileURL: The URL of the file to be uploaded.
    ///   - fileHelper: A helper object for file-related operations.
    /// - Returns: A tuple containing the configured `URLRequest` and the file URL used for the upload.
    /// - Throws: An error if the upload preparation fails.
    func configureRequestForUpload(
        request: URLRequest,
        httpOptions: IONFLTRHttpOptions,
        uploadOptions: IONFLTRUploadOptions,
        fileURL: URL,
        fileHelper: IONFLTRFileHelper = IONFLTRFileHelper()
    ) throws -> (URLRequest, URL) {
        let boundary = "++++IONFLTRBoundary"
        var request = request
        var isMultipartUpload = false

        if (!httpOptions.headers.keys.contains("Content-Type")) {
            if request.httpMethod?.uppercased() == "POST" || request.httpMethod?.uppercased() == "PUT" {
                isMultipartUpload = true
                request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            } else {
                let mimeType = uploadOptions.mimeType ?? fileHelper.mimeType(for: fileURL) ?? "application/octet-stream"
                request.setValue(mimeType, forHTTPHeaderField: "Content-Type")
            }
        }
        
        let fileLength = getFileSize(from: fileURL)

        if uploadOptions.chunkedMode {
            request.setContentLengthHeader(httpOptions: httpOptions, contentLength: fileLength)
            return (request, fileURL)
        } else if isMultipartUpload {
            let httpBody = try createMultipartBody(uploadOptions: uploadOptions, fileURL: fileURL, fileHelper: fileHelper, boundary: boundary)
            let tempFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("multipart_\(UUID().uuidString).tmp")
            request.setContentLengthHeader(httpOptions: httpOptions, contentLength: Int64(httpBody.count))
            try httpBody.write(to: tempFileURL)
            return (request, tempFileURL)
        }

        request.setContentLengthHeader(httpOptions: httpOptions, contentLength: fileLength)
        return (request, fileURL)
    }

    /// Builds query items from HTTP options.
    ///
    /// - Parameter options: The HTTP options containing query parameters.
    /// - Returns: An array of `URLQueryItem` objects.
    func buildQueryItems(from options: IONFLTRHttpOptions) -> [URLQueryItem] {
        return options.params.flatMap { key, values in
            values.map { value in
                URLQueryItem(name: key, value: value)
            }
        }
    }
    
    /// Builds an HTTP body from HTTP options.
    ///
    /// - Parameter options: The HTTP options containing parameters.
    /// - Returns: A `Data` object representing the HTTP body.
    func buildHttpBody(from options: IONFLTRHttpOptions) -> Data? {
        let paramString = options.params.flatMap { key, values in
            values.map { value in
                let encodedKey = encode(key, shouldEncode: options.shouldEncodeUrlParams)
                let encodedValue = encode(value, shouldEncode: options.shouldEncodeUrlParams)
                return "\(encodedKey)=\(encodedValue)"
            }
        }.joined(separator: "&")
        return paramString.data(using: .utf8)
    }
    
    /// Encodes a string for use in a URL.
    ///
    /// - Parameters:
    ///   - string: The string to encode.
    ///   - shouldEncode: A flag indicating whether the string should be encoded.
    /// - Returns: The encoded string.
    func encode(_ string: String, shouldEncode: Bool) -> String {
        guard shouldEncode else { return string }
        return string.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? string
    }
    
    /// Creates a multipart body for a file upload.
    ///
    /// - Parameters:
    ///   - uploadOptions: The upload options specifying MIME type, file key, and form parameters.
    ///   - fileURL: The URL of the file to be included in the multipart body.
    ///   - fileHelper: A helper object for file-related operations.
    ///   - boundary: The boundary string used to separate parts in the multipart body.
    /// - Returns: A `Data` object representing the multipart body.
    /// - Throws: An error if the body creation fails.
    func createMultipartBody(
        uploadOptions: IONFLTRUploadOptions,
        fileURL: URL,
        fileHelper: IONFLTRFileHelper = IONFLTRFileHelper(),
        boundary: String
    ) throws -> Data {
        let lineEnd = "\r\n"
        var body = Data()

        uploadOptions.formParams?.forEach({ (key: String, value: String) in
            body.append("--\(boundary)\(lineEnd)")
            body.append("Content-Disposition: form-data; name=\"\(key)\"\(lineEnd)\(lineEnd)")
            body.append("\(value)\(lineEnd)")
        })

        let fileData = try Data(contentsOf: fileURL)
        body.append("--\(boundary)\(lineEnd)")
        body.append("Content-Disposition: form-data; name=\"\(uploadOptions.fileKey)\"; filename=\"\(fileURL.lastPathComponent)\"\(lineEnd)")
        let mimeType = uploadOptions.mimeType ?? fileHelper.mimeType(for: fileURL) ?? "application/octet-stream"
        body.append("Content-Type: \(mimeType)\(lineEnd)\(lineEnd)")
        body.append(fileData)
        body.append(lineEnd)

        body.append("--\(boundary)--\(lineEnd)".data(using: .utf8)!)
        return body
    }
    
    private func getFileSize(from url: URL) -> Int64 {
        do {
            return try FileManager.default.attributesOfItem(atPath: url.path)[.size] as! Int64
        } catch {
            return 0
        }
    }
}

private extension URLRequest {
    mutating func setContentLengthHeader(
        httpOptions: IONFLTRHttpOptions,
        contentLength: Int64
    ) {
        if (!httpOptions.headers.keys.contains("Content-Length") && contentLength > 0) {
            setValue(String(contentLength), forHTTPHeaderField: "Content-Length")
        }
    }
}

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
