import Foundation

enum SocialPlatform {
    case facebook
    case linkedin
    case instagram
    case x

    var allowedHosts: Set<String> {
        switch self {
        case .facebook:
            return ["facebook.com"]
        case .linkedin:
            return ["linkedin.com"]
        case .instagram:
            return ["instagram.com"]
        case .x:
            return ["x.com", "twitter.com"]
        }
    }
}

enum SocialLinkValidator {
    static func normalize(_ rawValue: String, platform: SocialPlatform) -> String? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let candidate: String
        if trimmed.contains("://") {
            candidate = trimmed
        } else {
            candidate = "https://\(trimmed)"
        }

        guard
            let components = URLComponents(string: candidate),
            let scheme = components.scheme?.lowercased(),
            scheme == "http" || scheme == "https",
            let host = components.host?.lowercased(),
            isAllowedHost(host, for: platform.allowedHosts),
            let url = components.url
        else {
            return nil
        }

        return url.absoluteString
    }

    private static func isAllowedHost(_ host: String, for allowedHosts: Set<String>) -> Bool {
        for allowedHost in allowedHosts {
            if host == allowedHost || host.hasSuffix(".\(allowedHost)") {
                return true
            }
        }
        return false
    }
}
