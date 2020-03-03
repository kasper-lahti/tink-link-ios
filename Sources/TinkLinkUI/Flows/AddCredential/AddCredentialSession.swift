import UIKit
import TinkLink

final class AddCredentialSession {

    weak var parentViewController: UIViewController?

    private let credentialController: CredentialController

    private var task: AddCredentialTask?
    private var supplementInfoTask: SupplementInformationTask?

    private var statusViewController: AddCredentialStatusViewController?
    private weak var qrImageViewController: QRImageViewController?
    private var statusPresentationManager = AddCredentialStatusPresentationManager()

    init(credentialController: CredentialController, parentViewController: UIViewController) {
        self.parentViewController = parentViewController
        self.credentialController = credentialController
    }

    deinit {
        task?.cancel()
    }

    func addCredential(provider: Provider, form: Form, allowAnotherDevice: Bool, onCompletion: @escaping ((Result<Void, Error>) -> Void)) {

        task = credentialController.addCredential(
            provider,
            form: form,
            progressHandler: { [weak self] status in
                DispatchQueue.main.async {
                    self?.handleAddCredentialStatus(status, shouldAuthenticateInAnotherDevice: allowAnotherDevice)
                }
            },
            completion: { [weak self] result in
                DispatchQueue.main.async {
                    self?.handleAddCredentialCompletion(result, onCompletion: onCompletion)
                }
            }
        )
        // TODO: Copy
        self.showUpdating(status: "Authorizing...")
    }
    private func handleAddCredentialStatus(_ status: AddCredentialTask.Status, shouldAuthenticateInAnotherDevice: Bool = false) {
        switch status {
        case .created, .authenticating:
            break
        case .awaitingSupplementalInformation(let supplementInformationTask):
            showSupplementalInformation(for: supplementInformationTask)
        case .awaitingThirdPartyAppAuthentication(let thirdPartyAppAuthenticationTask):
            if shouldAuthenticateInAnotherDevice {
                thirdPartyAppAuthenticationTask.qr { [weak self] qrImage in
                    DispatchQueue.main.async {
                        self?.showQRCodeView(qrImage: qrImage)
                    }
                }
            } else {
                thirdPartyAppAuthenticationTask.openThirdPartyApp { [weak self] in
                    DispatchQueue.main.async {
                        self?.showUpdating(status: "Waiting for authentication on another device")
                    }
                }
            }
        case .updating(let status):
            showUpdating(status: status)
        }
    }

    private func handleAddCredentialCompletion(_ result: Result<Credential, Error>, onCompletion: @escaping ((Result<Void, Error>) -> Void)) {
        do {
            _ = try result.get()
            hideUpdatingView(animated: true) {
                onCompletion(.success(()))
            }
        } catch {
            self.hideUpdatingView(animated: true) {
                onCompletion(.failure(error))
            }
        }
        task = nil
    }
}

extension AddCredentialSession {
    private func showSupplementalInformation(for supplementInformationTask: SupplementInformationTask) {
        self.supplementInfoTask = supplementInformationTask
        hideUpdatingView(animated: true) {
            let supplementalInformationViewController = SupplementalInformationViewController(supplementInformationTask: supplementInformationTask)
            supplementalInformationViewController.delegate = self
            let navigationController = TinkNavigationController(rootViewController: supplementalInformationViewController)
            self.parentViewController?.show(navigationController, sender: nil)
        }
    }

    private func showUpdating(status: String) {
        hideQRCodeView {
            if let statusViewController = self.statusViewController {
                if statusViewController.presentingViewController == nil {
                    self.parentViewController?.present(statusViewController, animated: true)
                }
            } else {
                let statusViewController = AddCredentialStatusViewController()
                statusViewController.modalTransitionStyle = .crossDissolve
                statusViewController.modalPresentationStyle = .custom
                statusViewController.transitioningDelegate = self.statusPresentationManager
                self.parentViewController?.present(statusViewController, animated: true)
                self.statusViewController = statusViewController
            }
            self.statusViewController?.status = status
        }
    }

    private func hideUpdatingView(animated: Bool = false, completion: (() -> Void)? = nil) {
        hideQRCodeView(animated: animated)
        guard statusViewController != nil, statusViewController?.presentingViewController != nil else {
            completion?()
            return
        }
        parentViewController?.dismiss(animated: animated, completion: completion)
    }

    private func showQRCodeView(qrImage: UIImage) {
        hideUpdatingView {
            let qrImageViewController = QRImageViewController(qrImage: qrImage)
            self.qrImageViewController = qrImageViewController
            self.parentViewController?.present(TinkNavigationController(rootViewController: qrImageViewController), animated: true)
        }
    }

    private func hideQRCodeView(animated: Bool = false, completion: (() -> Void)? = nil) {
        guard qrImageViewController != nil else {
            completion?()
            return
        }
        parentViewController?.dismiss(animated: animated, completion: completion)
        qrImageViewController = nil
    }
}

// MARK: - SupplementalInformationViewControllerDelegate

extension AddCredentialSession: SupplementalInformationViewControllerDelegate {
    func supplementalInformationViewControllerDidCancel(_ viewController: SupplementalInformationViewController) {
        parentViewController?.dismiss(animated: true) {
            self.supplementInfoTask?.cancel()
            self.showUpdating(status: "Canceling...")
        }
    }

    func supplementalInformationViewController(_ viewController: SupplementalInformationViewController, didPressSubmitWithForm form: Form) {
        parentViewController?.dismiss(animated: true) {
            self.supplementInfoTask?.submit(form)
            self.showUpdating(status: "Sending...")
        }
    }
}
