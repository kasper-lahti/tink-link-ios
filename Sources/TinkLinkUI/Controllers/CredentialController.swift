import TinkLinkSDK
import Foundation

extension Notification.Name {
    static let credentialControllerDidAddCredential = Notification.Name("CredentialControllerDidAddCredential")
    static let credentialControllerDidUpdateStatus = Notification.Name("CredentialControllerDidUpdateStatus")
    static let credentialControllerDidSupplementInformation = Notification.Name("CredentialControllerDidSupplementInformation")
    static let credentialControllerDidUpdateQRCode = Notification.Name("CredentialControllerDidUpdateQRCode")
    static let credentialControllerDidError = Notification.Name("CredentialControllerDidError")
}

final class CredentialController {
    let tinkLink: TinkLink

    var user: User?

    private(set) var supplementInformationTask: SupplementInformationTask?
    private(set) var qrCodeData: Data?

    private(set) var credentialContext: CredentialContext?
    private var addCredentialTask: AddCredentialTask?

    init(tinkLink: TinkLink) {
        self.tinkLink = tinkLink
    }

    func addCredential(_ provider: Provider, form: Form, shouldAuthenticateInAnotherDevice: Bool = false) {
        guard let user = user else { return }
        if credentialContext == nil {
            credentialContext = CredentialContext(user: user)
        }
        addCredentialTask = credentialContext?.addCredential(
            for: provider,
            form: form,
            progressHandler: { [weak self] in self?.createProgressHandler(for: $0, shouldAuthenticateInAnotherDevice: shouldAuthenticateInAnotherDevice) },
            completion: { [weak self] in self?.createCompletionHandler(result: $0) }
        )
    }

    func cancelAddCredential() {
        addCredentialTask?.cancel()
    }

    private func createProgressHandler(for status: AddCredentialTask.Status, shouldAuthenticateInAnotherDevice: Bool) {
        switch status {
        case .authenticating, .created:
            break
        case .awaitingSupplementalInformation(let supplementInformationTask):
            self.supplementInformationTask = supplementInformationTask
            NotificationCenter.default.post(name: .credentialControllerDidSupplementInformation, object: nil)
        case .awaitingThirdPartyAppAuthentication(let thirdPartyAppAuthenticationTask):
            if shouldAuthenticateInAnotherDevice {
                thirdPartyAppAuthenticationTask.qr { [weak self] result in
                    self?.qrCodeData = try? result.get()
                    NotificationCenter.default.post(name: .credentialControllerDidUpdateQRCode, object: nil)
                }
            } else {
                 thirdPartyAppAuthenticationTask.openThirdPartyApp()
            }
        case .updating(let status):
            let parameters = ["status": status]
            NotificationCenter.default.post(name: .credentialControllerDidUpdateStatus, object: nil, userInfo: parameters)
        }
    }

    private func createCompletionHandler(result: Result<Credential, Error>) {
        supplementInformationTask = nil
        qrCodeData = nil
        do {
            let credential = try result.get()
            NotificationCenter.default.post(name: .credentialControllerDidAddCredential, object: nil, userInfo: ["id": credential.id.value])
        } catch {
            let parameters = ["error": error]
            NotificationCenter.default.post(name: .credentialControllerDidError, object: nil, userInfo: parameters)
        }
    }
}
