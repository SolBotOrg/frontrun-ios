import Foundation
import Postbox
import SwiftSignalKit

public enum AIProvider: String, Codable, CaseIterable {
    case openai = "openai"
    case anthropic = "anthropic"
    case custom = "custom"

    public var displayName: String {
        switch self {
        case .openai:
            return "OpenAI"
        case .anthropic:
            return "Claude"
        case .custom:
            return "Custom"
        }
    }

    public var defaultEndpoint: String {
        switch self {
        case .openai:
            return "https://api.openai.com/v1"
        case .anthropic:
            return "https://api.anthropic.com/v1"
        case .custom:
            return ""
        }
    }

    public var defaultModel: String {
        switch self {
        case .openai:
            return "gpt-4o-mini"
        case .anthropic:
            return "claude-sonnet-4-20250514"
        case .custom:
            return ""
        }
    }
}

public enum SummaryMessageCount: Int, Codable, CaseIterable {
    case fifty = 50
    case hundred = 100
    case twoHundred = 200
    case fiveHundred = 500

    public var displayName: String {
        return "\(self.rawValue) messages"
    }
}

public struct AIConfiguration: Codable, Equatable {
    public var provider: AIProvider
    public var apiKey: String
    public var baseURL: String
    public var model: String
    public var enabled: Bool

    // Summary settings
    public var summaryMessageCount: SummaryMessageCount
    public var summaryPrompt: String

    public static let defaultSummaryPrompt = """
You are a helpful assistant that summarizes chat conversations. Analyze the messages and provide a clear, concise summary including:
- Main discussion topics
- Key points and decisions made
- Any action items or important information
- Overall tone/atmosphere of the conversation

Format the summary using markdown with headers (##, ###), bullet points (-), and bold (**text**) for emphasis.
"""

    public init(
        provider: AIProvider = .openai,
        apiKey: String = "",
        baseURL: String = "",
        model: String = "",
        enabled: Bool = false,
        summaryMessageCount: SummaryMessageCount = .hundred,
        summaryPrompt: String = ""
    ) {
        self.provider = provider
        self.apiKey = apiKey
        self.baseURL = baseURL.isEmpty ? provider.defaultEndpoint : baseURL
        self.model = model.isEmpty ? provider.defaultModel : model
        self.enabled = enabled
        self.summaryMessageCount = summaryMessageCount
        self.summaryPrompt = summaryPrompt.isEmpty ? AIConfiguration.defaultSummaryPrompt : summaryPrompt
    }

    public var isValid: Bool {
        return !apiKey.isEmpty && !baseURL.isEmpty && !model.isEmpty
    }

    public var effectiveSummaryPrompt: String {
        return summaryPrompt.isEmpty ? AIConfiguration.defaultSummaryPrompt : summaryPrompt
    }

    public func buildEndpointURL() -> String {
        var url = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove trailing slash
        if url.hasSuffix("/") {
            url = String(url.dropLast())
        }

        // Add /v1 if not present
        if !url.contains("/v1") {
            url += "/v1"
        }

        // Add the specific endpoint based on provider
        switch provider {
        case .openai, .custom:
            if !url.hasSuffix("/chat/completions") {
                url += "/chat/completions"
            }
        case .anthropic:
            if !url.hasSuffix("/messages") {
                url += "/messages"
            }
        }

        return url
    }
}

public final class AIConfigurationStorage {
    private let userDefaultsKey = "telegram.ai.configuration"

    public static let shared = AIConfigurationStorage()

    private init() {}

    public func getConfiguration() -> AIConfiguration {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let config = try? JSONDecoder().decode(AIConfiguration.self, from: data) else {
            return AIConfiguration()
        }
        return config
    }

    public func saveConfiguration(_ config: AIConfiguration) {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
            UserDefaults.standard.synchronize()
        }
    }

    public func getConfigurationSignal() -> Signal<AIConfiguration, NoError> {
        return Signal { subscriber in
            subscriber.putNext(self.getConfiguration())
            subscriber.putCompletion()
            return EmptyDisposable
        }
    }
}
