import Foundation
import WebKit

/// Built-in ad and tracker blocking for every web view in the app.
@MainActor
enum ContentBlocker {
    static let settingKey = "blockAds"

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: settingKey) as? Bool ?? true
    }

    private static let identifier = "Tinkerdock.ContentBlocker.v1"
    private static var compiled: Task<WKContentRuleList?, Never>?

    private static let adHosts = [
        "doubleclick.net", "googlesyndication.com", "googleadservices.com", "adservice.google.com",
        "amazon-adsystem.com", "criteo.net", "criteo.com", "adnxs.com", "confiant-integrations.net",
        "ay.delivery", "rubiconproject.com", "pubmatic.com", "openx.net", "casalemedia.com",
        "smartadserver.com", "yieldlove.com", "adsrvr.org", "3lift.com", "teads.tv", "taboola.com",
        "outbrain.com", "moatads.com", "scorecardresearch.com", "quantserve.com", "sharethrough.com",
    ]

    private static let siteRules: [(domains: [String], selector: String)] = [
        (["*kleinanzeigen.de"], "[data-liberty-position-name], .liberty-hide-unfilled, .site-base--left-banner, .site-base--right-banner, #btf-billboard"),
    ]

    private static let genericSelector = ".adsbygoogle, [id^='div-gpt-ad'], iframe[id^='google_ads_iframe']"

    /// Adds the rules to the web view's configuration before its first page loads.
    static func install(on webView: WKWebView) async {
        guard isEnabled, let rules = await ruleList() else { return }
        webView.configuration.userContentController.add(rules)
    }

    private static func ruleList() async -> WKContentRuleList? {
        if let compiled { return await compiled.value }
        let task = Task { () -> WKContentRuleList? in
            guard let json = encodedRules() else { return nil }
            return try? await WKContentRuleListStore.default().compileContentRuleList(forIdentifier: identifier, encodedContentRuleList: json)
        }
        compiled = task
        return await task.value
    }

    private static func encodedRules() -> String? {
        var rules: [[String: Any]] = adHosts.map { host in
            let pattern = "^[htpsw]+://([a-z0-9-]+\\.)*" + host.replacingOccurrences(of: ".", with: "\\.") + "[/:]"
            return ["trigger": ["url-filter": pattern], "action": ["type": "block"]]
        }
        rules.append(["trigger": ["url-filter": "^https?://www\\.kleinanzeigen\\.de/liberty/"], "action": ["type": "block"]])
        for rule in siteRules {
            rules.append(["trigger": ["url-filter": ".*", "if-domain": rule.domains], "action": ["type": "css-display-none", "selector": rule.selector]])
        }
        rules.append(["trigger": ["url-filter": ".*"], "action": ["type": "css-display-none", "selector": genericSelector]])
        guard let data = try? JSONSerialization.data(withJSONObject: rules) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
