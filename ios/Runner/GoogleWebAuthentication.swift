import AuthenticationServices
import Flutter
import UIKit

/// Google uses an OS authentication session, not SFSafariViewController.
/// iOS captures the registered callback and dismisses the sheet itself.
final class GoogleWebAuthentication: NSObject, FlutterPlugin,
  ASWebAuthenticationPresentationContextProviding {
  private static let redirect = "io.supabase.auraquest://login-callback/"
  private let registrar: FlutterPluginRegistrar
  private var session: ASWebAuthenticationSession?
  private var pendingResult: FlutterResult?
  private var anchor: UIWindow?
  private var attempt: UUID?

  private init(registrar: FlutterPluginRegistrar) {
    self.registrar = registrar
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let plugin = GoogleWebAuthentication(registrar: registrar)
    let channel = FlutterMethodChannel(
      name: "uk.brenzel.auraquest/google-auth", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(plugin, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "authenticate":
      guard pendingResult == nil else {
        result(FlutterError(code: "in_progress", message: "Sign-in already in progress.", details: nil))
        return
      }
      guard let arguments = call.arguments as? [String: Any],
        let value = arguments["url"] as? String,
        let url = URL(string: value), url.scheme == "https",
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
        components.queryItems?.first(where: { $0.name == "provider" })?.value == "google",
        components.queryItems?.first(where: { $0.name == "redirect_to" })?.value == Self.redirect
      else {
        result(FlutterError(code: "invalid_url", message: "Invalid sign-in URL.", details: nil))
        return
      }
      guard let window = registrar.viewController?.viewIfLoaded?.window else {
        result(FlutterError(code: "unavailable", message: "No active app window.", details: nil))
        return
      }
      anchor = window
      pendingResult = result
      let currentAttempt = UUID()
      attempt = currentAttempt
      let completion: (URL?, Error?) -> Void = { [weak self] callback, error in
        DispatchQueue.main.async {
          self?.finish(callback: callback, error: error, attempt: currentAttempt)
        }
      }
      let authentication: ASWebAuthenticationSession
      if #available(iOS 17.4, *) {
        authentication = ASWebAuthenticationSession(
          url: url, callback: .customScheme("io.supabase.auraquest"), completionHandler: completion)
      } else {
        // Retain the app's existing iOS 15 minimum.
        authentication = ASWebAuthenticationSession(
          url: url, callbackURLScheme: "io.supabase.auraquest", completionHandler: completion)
      }
      authentication.presentationContextProvider = self
      authentication.prefersEphemeralWebBrowserSession = false
      session = authentication // The system requires a strong reference until completion.
      if !authentication.start() {
        finish(callback: nil, error: nil, attempt: currentAttempt)
      }
    case "cancel":
      let pending = pendingResult
      let authentication = session
      pendingResult = nil
      session = nil
      anchor = nil
      attempt = nil
      authentication?.cancel()
      pending?(FlutterError(code: "cancelled", message: "Sign-in cancelled.", details: nil))
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
    // Set from this Flutter engine's actual window before start().
    return anchor ?? ASPresentationAnchor()
  }

  private func finish(callback: URL?, error: Error?, attempt currentAttempt: UUID) {
    // An old cancellation callback must not complete a newer sign-in.
    guard attempt == currentAttempt, let result = pendingResult else { return }
    pendingResult = nil
    session = nil
    anchor = nil
    attempt = nil
    if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
      result(FlutterError(code: "cancelled", message: "Sign-in cancelled.", details: nil))
    } else if error != nil || callback == nil {
      // Never include callback URLs, provider codes or native error details in logs.
      result(FlutterError(code: "failed", message: "Could not complete sign-in.", details: nil))
    } else {
      result(callback!.absoluteString)
    }
  }
}
