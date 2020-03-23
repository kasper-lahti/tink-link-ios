import Foundation
import GRPC

protocol UserService {
    func createAnonymous(market: Market?, locale: Locale, origin: String?, completion: @escaping (Result<AccessToken, Error>) -> Void) -> RetryCancellable?
    func authenticate(code: AuthorizationCode, completion: @escaping (Result<AuthenticateResponse, Error>) -> Void) -> RetryCancellable?
    func userProfile(completion: @escaping (Result<UserProfile, Error>) -> Void) -> RetryCancellable?
}

final class RESTUserService {

    private let client: RESTClient

    init(client: RESTClient) {
        self.client = client
    }

    @discardableResult
    func userProfile(
        completion: @escaping (Result<RESTUserProfile, Error>) -> Void
    ) -> Cancellable? {
        let request = RESTResourceRequest(path: "/api/v1/user/profile", method: .get, contentType: .json, completion: completion)
        return client.performRequest(request)
    }

    @discardableResult
    func authenticate(code: AuthorizationCode, completion: @escaping (Result<AuthenticateResponse, Error>) -> Void) -> Cancellable? {
        var request = RESTResourceRequest(path: "/link/v1/authentication/token", method: .post, contentType: .json, completion: completion)
        let body = ["code": code.rawValue]
        request.body = try? JSONEncoder().encode(body)

        return client.performRequest(request)
    }
}

final class TinkUserService: UserService, TokenConfigurableService {

    let connection: ClientConnection
    var defaultCallOptions: CallOptions
    private let queue: DispatchQueue
    let restURL: URL

    private var session: URLSession
    private var sessionDelegate: URLSessionDelegate?

    convenience init(tink: Tink = .shared) {
        let client = tink.client
        self.init(
            connection: client.connection,
            defaultCallOptions: client.defaultCallOptions,
            queue: client.queue,
            restURL: client.restURL,
            certificates: client.restCertificateURL
                .flatMap { try? Data(contentsOf: $0) }
                .map { [$0] } ?? []
        )
    }

    init(connection: ClientConnection, defaultCallOptions: CallOptions, queue: DispatchQueue, restURL: URL, certificates: [Data]) {
        self.connection = connection
        self.defaultCallOptions = defaultCallOptions
        self.queue = queue
        self.restURL = restURL
        if certificates.isEmpty {
            self.session = .shared
        } else {
            self.sessionDelegate = CertificatePinningDelegate(certificates: certificates)
            self.session = URLSession(configuration: .ephemeral, delegate: sessionDelegate, delegateQueue: nil)
        }
    }

    private lazy var service = UserServiceServiceClient(connection: connection, defaultCallOptions: defaultCallOptions)

    func createAnonymous(market: Market? = nil, locale: Locale, origin: String? = nil, completion: @escaping (Result<AccessToken, Error>) -> Void) -> RetryCancellable? {
        var request = GRPCCreateAnonymousRequest()
        request.market = market?.code ?? ""
        request.locale = locale.identifier
        request.origin = origin ?? ""

        return CallHandler(for: request, method: service.createAnonymous, queue: queue, responseMap: { AccessToken($0.accessToken) }, completion: completion)
    }

    func authenticate(code: AuthorizationCode, completion: @escaping (Result<AuthenticateResponse, Error>) -> Void) -> RetryCancellable? {
        guard var urlComponents = URLComponents(url: restURL, resolvingAgainstBaseURL: false) else {
            preconditionFailure("Invalid restURL")
        }

        urlComponents.path = "/link/v1/authentication/token"
        var urlRequest = URLRequest(url: urlComponents.url!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")

        do {
            let body = ["code": code.rawValue]
            urlRequest.httpBody = try JSONEncoder().encode(body)
        } catch {
            completion(.failure(error))
            return nil
        }

        let serviceRetryCanceller = URLSessionRequestRetryCancellable<AuthenticateResponse, AuthorizationError>(session: session, request: urlRequest, completion: completion)
        serviceRetryCanceller.start()

        return serviceRetryCanceller
    }

    func userProfile(completion: @escaping (Result<UserProfile, Error>) -> Void) -> RetryCancellable? {
        let request = GRPCGetProfileRequest()
        return CallHandler(for: request, method: service.getProfile, queue: queue, responseMap: {UserProfile(grpcUserProfile: $0.userProfile)}, completion: completion)
    }
}
