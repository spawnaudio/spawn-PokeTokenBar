import Foundation
import Security
import AppKit

#if os(macOS)
import AuthenticationServices
#endif

struct GoogleOAuthTokens: Codable, Sendable, Equatable {
    var accessToken: String
    var refreshToken: String?
    var expiry: Date
}

enum GoogleCalendarAuthError: Error, Equatable {
    case notConfigured
    case cancelled
    case tokenExchange
    case transport
}

/// Installed-app OAuth for Google Calendar. Client id/secret live in UserDefaults (Settings).
enum GoogleCalendarAuth {
    static let clientIDKey = "googleCalendarClientID"
    static let clientSecretKey = "googleCalendarClientSecret"
    static let redirectURI = "poketokenbar://oauth"
    static let scope = "https://www.googleapis.com/auth/calendar.events"

    static var clientID: String {
        (UserDefaults.standard.string(forKey: clientIDKey) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static var clientSecret: String {
        (UserDefaults.standard.string(forKey: clientSecretKey) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static var isConfigured: Bool { !clientID.isEmpty }

    static func authorizationURL() throws -> URL {
        guard isConfigured else { throw GoogleCalendarAuthError.notConfigured }
        var comps = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        comps.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
        ]
        guard let url = comps.url else { throw GoogleCalendarAuthError.notConfigured }
        return url
    }

    static func exchangeCode(_ code: String) async throws -> GoogleOAuthTokens {
        guard isConfigured else { throw GoogleCalendarAuthError.notConfigured }
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var parts = [
            "code=\(urlEncode(code))",
            "client_id=\(urlEncode(clientID))",
            "redirect_uri=\(urlEncode(redirectURI))",
            "grant_type=authorization_code",
        ]
        if !clientSecret.isEmpty {
            parts.append("client_secret=\(urlEncode(clientSecret))")
        }
        request.httpBody = parts.joined(separator: "&").data(using: .utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw GoogleCalendarAuthError.tokenExchange
        }
        return try parseTokens(data)
    }

    static func refresh(_ tokens: GoogleOAuthTokens) async throws -> GoogleOAuthTokens {
        guard let refresh = tokens.refreshToken, !refresh.isEmpty else {
            throw GoogleCalendarAuthError.notConfigured
        }
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var parts = [
            "refresh_token=\(urlEncode(refresh))",
            "client_id=\(urlEncode(clientID))",
            "grant_type=refresh_token",
        ]
        if !clientSecret.isEmpty {
            parts.append("client_secret=\(urlEncode(clientSecret))")
        }
        request.httpBody = parts.joined(separator: "&").data(using: .utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw GoogleCalendarAuthError.tokenExchange
        }
        var next = try parseTokens(data)
        if next.refreshToken == nil { next.refreshToken = refresh }
        return next
    }

    static func parseTokens(_ data: Data) throws -> GoogleOAuthTokens {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let access = json["access_token"] as? String, !access.isEmpty
        else { throw GoogleCalendarAuthError.tokenExchange }
        let expiresIn = (json["expires_in"] as? NSNumber)?.doubleValue ?? 3600
        return GoogleOAuthTokens(
            accessToken: access,
            refreshToken: json["refresh_token"] as? String,
            expiry: Date().addingTimeInterval(expiresIn - 60))
    }

    private static func urlEncode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
    }
}

enum GoogleTokenStore {
    private static let service = "io.github.chattymin.poketokenbar.google-calendar"
    private static let account = "oauth"

    static func load() -> GoogleOAuthTokens? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        let status = KeychainReader.copyMatching(query, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(GoogleOAuthTokens.self, from: data)
    }

    static func save(_ tokens: GoogleOAuthTokens) {
        guard let data = try? JSONEncoder().encode(tokens) else { return }
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(base as CFDictionary)
        var add = base
        add[kSecValueData as String] = data
        SecItemAdd(add as CFDictionary, nil)
    }

    static func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

#if os(macOS)
@MainActor
final class GoogleOAuthPresenter: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        NSApp.windows.first { $0.isVisible } ?? ASPresentationAnchor()
    }

    func signIn() async throws -> GoogleOAuthTokens {
        let authURL = try GoogleCalendarAuth.authorizationURL()
        let callback = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "poketokenbar"
            ) { url, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let url else {
                    continuation.resume(throwing: GoogleCalendarAuthError.cancelled)
                    return
                }
                continuation.resume(returning: url)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.session = session
            if !session.start() {
                self.session = nil
                continuation.resume(throwing: GoogleCalendarAuthError.cancelled)
            }
        }
        session = nil
        let comps = URLComponents(url: callback, resolvingAgainstBaseURL: false)
        guard let code = comps?.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw GoogleCalendarAuthError.cancelled
        }
        let tokens = try await GoogleCalendarAuth.exchangeCode(code)
        GoogleTokenStore.save(tokens)
        return tokens
    }
}
#endif
