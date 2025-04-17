public typealias HttpParams = [String: [String]]
public typealias HttpHeaders = [String: String]

/// Represents HTTP configuration options for file transfer operations.
///
/// The `IONFLTRHttpOptions` struct provides a way to configure HTTP requests, including
/// the HTTP method, parameters, headers, timeout, and other options.
public struct IONFLTRHttpOptions {
    
    /// Creates a new instance of `IONFLTRHttpOptions` with the specified configuration.
    ///
    /// - Parameters:
    ///   - method: The HTTP method to be used (e.g., "GET", "POST").
    ///   - params: The HTTP parameters to be included in the request. Defaults to an empty dictionary.
    ///   - headers: The HTTP headers to be included in the request. Defaults to an empty dictionary.
    ///   - timeout: The timeout interval for the HTTP request, in seconds. Defaults to 60 seconds.
    ///   - disableRedirects: A flag indicating whether HTTP redirects should be disabled. Defaults to `false`.
    ///   - shouldEncodeUrlParams: A flag indicating whether URL parameters should be encoded. Defaults to `true`.
    public init(
        method: String,
        params: HttpParams = [:],
        headers: HttpHeaders = [:],
        timeout: Int = 60,
        disableRedirects: Bool = false,
        shouldEncodeUrlParams: Bool = true
    ) {
        self.method = method
        self.params = params
        self.headers = headers
        self.timeout = timeout
        self.disableRedirects = disableRedirects
        self.shouldEncodeUrlParams = shouldEncodeUrlParams
    }
    
    /// The HTTP method to be used (e.g., "GET", "POST").
    var method: String

    /// The HTTP parameters to be included in the request.
    ///
    /// Defaults to an empty dictionary.
    var params: HttpParams

    /// The HTTP headers to be included in the request.
    ///
    /// Defaults to an empty dictionary.
    var headers: HttpHeaders

    /// The timeout interval for the HTTP request, in seconds.
    ///
    /// Defaults to 60 seconds.
    var timeout: Int

    /// A flag indicating whether HTTP redirects should be disabled.
    ///
    /// Defaults to `false`.
    var disableRedirects: Bool

    /// A flag indicating whether URL parameters should be encoded.
    ///
    /// Defaults to `true`.
    var shouldEncodeUrlParams: Bool
}
