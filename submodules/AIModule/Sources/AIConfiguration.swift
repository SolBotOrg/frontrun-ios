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
            return "claude-sonnet-4-5-20250929"
        case .custom:
            return ""
        }
    }
}

public enum SummaryMessageCount: Codable, Equatable, CaseIterable {
    case fifty
    case hundred
    case twoHundred
    case fiveHundred
    case custom(Int)

    public static var allCases: [SummaryMessageCount] {
        return [.fifty, .hundred, .twoHundred, .fiveHundred]
    }

    public var value: Int {
        switch self {
        case .fifty: return 50
        case .hundred: return 100
        case .twoHundred: return 200
        case .fiveHundred: return 500
        case .custom(let count): return count
        }
    }

    public var displayName: String {
        switch self {
        case .custom(let count):
            return "\(count) messages (custom)"
        default:
            return "\(self.value) messages"
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(Int.self)
        switch value {
        case 50: self = .fifty
        case 100: self = .hundred
        case 200: self = .twoHundred
        case 500: self = .fiveHundred
        default: self = .custom(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.value)
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
