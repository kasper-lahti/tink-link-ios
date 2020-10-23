@_exported import TinkCore
import Foundation

extension Tink {
    // MARK: - Handling Redirects

    ///
    /// For some providers the redirect needs to be a https link. Use the continue user activity method in your `UIApplicationDelegate` to let TinkLink send the information to Tink if needed.
    ///
    /// ```swift
    /// func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
    ///     if userActivity.activityType == NSUserActivityTypeBrowsingWeb, let url = userActivity.webpageURL {
    ///         return TinkLink.shared.open(url)
    ///     } else {
    ///         return false
    ///     }
    /// }
    /// ```
    @available(iOS 9.0, *)
    @available(*, deprecated, message: "Use Tink.open(_:completion:) instead.")
    public func open(_ url: URL, completion: ((Result<Void, Error>) -> Void)? = nil) -> Bool {
        Tink.open(url, completion: completion)
    }

    ///
    /// For some providers the redirect needs to be a https link. Use the continue user activity method in your `UIApplicationDelegate` to let TinkLink send the information to Tink if needed.
    ///
    /// ```swift
    /// func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
    ///     if userActivity.activityType == NSUserActivityTypeBrowsingWeb, let url = userActivity.webpageURL {
    ///         return TinkLink.shared.open(url)
    ///     } else {
    ///         return false
    ///     }
    /// }
    /// ```
    @available(iOS 9.0, *)
    public static func open(_ url: URL, completion: ((Result<Void, Error>) -> Void)? = nil) -> Bool {
        guard let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false),
              urlComponents.string?.starts(with: configuration.redirectURI.absoluteString) ?? false
        else { return false }

        var parameters = Dictionary(grouping: urlComponents.queryItems ?? [], by: { $0.name })
            .compactMapValues { $0.first?.value }

        parameters.merge(urlComponents.fragmentParameters, uniquingKeysWith: { current, _ in current })

        NotificationCenter.default.post(name: .credentialThirdPartyCallback, object: nil, userInfo: parameters)

        return true
    }
}
