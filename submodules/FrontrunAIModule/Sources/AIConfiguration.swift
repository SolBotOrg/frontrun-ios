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
    case hundred
    case threeHundred
    case fiveHundred
    case thousand
    case twoThousand
    case threeThousand
    case custom(Int)

    public static var allCases: [SummaryMessageCount] {
        return [.hundred, .threeHundred, .fiveHundred, .thousand, .twoThousand, .threeThousand]
    }

    public static let minValue: Int = 100
    public static let maxValue: Int = 3000

    public var value: Int {
        switch self {
        case .hundred: return 100
        case .threeHundred: return 300
        case .fiveHundred: return 500
        case .thousand: return 1000
        case .twoThousand: return 2000
        case .threeThousand: return 3000
        case .custom(let count): return min(max(count, SummaryMessageCount.minValue), SummaryMessageCount.maxValue)
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
        case 100: self = .hundred
        case 300: self = .threeHundred
        case 500: self = .fiveHundred
        case 1000: self = .thousand
        case 2000: self = .twoThousand
        case 3000: self = .threeThousand
        default: self = .custom(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.value)
    }
}

public struct AIConfiguration: Equatable {
    public var provider: AIProvider
    public var apiKey: String
    public var baseURL: String
    public var model: String
    public var enabled: Bool

    // Summary settings
    public var summaryMessageCount: SummaryMessageCount
    public var summarySystemPrompt: String
    public var summaryUserPrompt: String

    // Legacy support for migration
    public var summaryPrompt: String {
        get { return summarySystemPrompt }
        set { summarySystemPrompt = newValue }
    }

    public static let defaultSummarySystemPrompt = """
You are a professional group chat analyst. Analyze the chat messages and generate a structured summary.

## Input Format
Each message is formatted as: [id:MESSAGE_ID][TIME] Username: Content
Example: [id:12345][2025-01-22 12:05] 张三: 这个代币看起来不错

## Output Format Requirements:

**1. Title (first line):** A concise title summarizing the main topic

**2. Overview:** A 1-2 sentence high-level summary of the entire conversation

**3. Hot Topics:** List main discussion topics

**4. Tokens Mentioned (if any):** List all crypto tokens/addresses mentioned

### Example Output:

加密货币交易动态与市场讨论

**概述:** 群成员主要讨论了近期热门MEME币的走势和交易机会，情绪偏向乐观，多人分享了盈利经验。

### Hot Topics

**1. [Topic Title]**
• Time: 今天 14:25 - 14:36
• Summary: <user m="12345">张三</user>分享了某代币的上涨信息，<user m="12346">李四</user>表示看好后市。

**2. [Next Topic Title]**
...

### Tokens Mentioned
• <token>0x1234567890abcdef1234567890abcdef12345678</token> - 代币名称/描述
• <token>另一个地址</token> - 描述

## CRITICAL Rules for <user> tags:
- When mentioning a KEY user in Summary, use: <user m="MESSAGE_ID">用户名</user>
- MESSAGE_ID is from the [id:XXX] prefix of the message
- Only tag users with important messages (2-4 per topic max)
- Copy the EXACT username, do not modify

## CRITICAL Rules for <token> tags:
- Wrap ONLY the FULL token address/contract address: <token>FULL_ADDRESS</token>
- ALWAYS use the COMPLETE address, NEVER truncate or abbreviate with "..." or "*"
- Do NOT include any other text inside <token> tags
- Good: <token>0x1234567890abcdef1234567890abcdef12345678</token>（代币名称）
- Bad: <token>0x1234...5678</token> - DO NOT truncate addresses
- Bad: <token>0x1234***5678</token> - DO NOT mask addresses
- Bad: <token>0x1234567890abcdef（代币名称）</token> - DO NOT include token name inside tag

## Other Rules:
- Do NOT include "Participants" list - it's redundant
- Extract 3-8 main topics based on content
- Time format: relative time like "昨天 11:44" or "今天 09:00 - 10:30"
- Keep summaries concise but informative
- Use Chinese for output if chat is primarily in Chinese
- DO NOT show thinking process, only output final summary
"""

    public init(
        provider: AIProvider = .openai,
        apiKey: String = "",
        baseURL: String = "",
        model: String = "",
        enabled: Bool = false,
        summaryMessageCount: SummaryMessageCount = .hundred,
        summarySystemPrompt: String = "",
        summaryUserPrompt: String = ""
    ) {
        self.provider = provider
        self.apiKey = apiKey
        self.baseURL = baseURL.isEmpty ? provider.defaultEndpoint : baseURL
        self.model = model.isEmpty ? provider.defaultModel : model
        self.enabled = enabled
        self.summaryMessageCount = summaryMessageCount
        self.summarySystemPrompt = summarySystemPrompt
        self.summaryUserPrompt = summaryUserPrompt
    }

    // Coding keys for migration support
    private enum CodingKeys: String, CodingKey {
        case provider
        case apiKey
        case baseURL
        case model
        case enabled
        case summaryMessageCount
        case summarySystemPrompt
        case summaryUserPrompt
        case summaryPrompt // Legacy key
    }
}

extension AIConfiguration: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        provider = try container.decodeIfPresent(AIProvider.self, forKey: .provider) ?? .openai
        apiKey = try container.decodeIfPresent(String.self, forKey: .apiKey) ?? ""
        baseURL = try container.decodeIfPresent(String.self, forKey: .baseURL) ?? provider.defaultEndpoint
        model = try container.decodeIfPresent(String.self, forKey: .model) ?? provider.defaultModel
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        summaryMessageCount = try container.decodeIfPresent(SummaryMessageCount.self, forKey: .summaryMessageCount) ?? .hundred
        summaryUserPrompt = try container.decodeIfPresent(String.self, forKey: .summaryUserPrompt) ?? ""

        // Handle migration from old summaryPrompt to new summarySystemPrompt
        if let systemPrompt = try container.decodeIfPresent(String.self, forKey: .summarySystemPrompt) {
            summarySystemPrompt = systemPrompt
        } else if let legacyPrompt = try container.decodeIfPresent(String.self, forKey: .summaryPrompt) {
            // Migrate from legacy summaryPrompt
            summarySystemPrompt = legacyPrompt
        } else {
            summarySystemPrompt = ""
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(provider, forKey: .provider)
        try container.encode(apiKey, forKey: .apiKey)
        try container.encode(baseURL, forKey: .baseURL)
        try container.encode(model, forKey: .model)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(summaryMessageCount, forKey: .summaryMessageCount)
        try container.encode(summarySystemPrompt, forKey: .summarySystemPrompt)
        try container.encode(summaryUserPrompt, forKey: .summaryUserPrompt)
    }

    public var isValid: Bool {
        return !apiKey.isEmpty && !baseURL.isEmpty && !model.isEmpty
    }

    public var effectiveSummarySystemPrompt: String {
        return summarySystemPrompt.isEmpty ? AIConfiguration.defaultSummarySystemPrompt : summarySystemPrompt
    }

    // Legacy compatibility
    public var effectiveSummaryPrompt: String {
        return effectiveSummarySystemPrompt
    }

    /// Get context window size (in tokens) for a given model
    /// Returns the maximum context size based on model name matching
    /// Updated: 2025-01 with latest model specs
    public static func getContextSize(for model: String) -> Int {
        let modelLower = model.lowercased()

        // ==================== OpenAI Models ====================

        // GPT-5 series (400K context)
        if modelLower.contains("gpt-5") || modelLower.contains("gpt5") {
            return 400000
        }

        // o1/o3 reasoning models (200K context)
        if modelLower.contains("o1-mini") {
            return 128000
        }
        if modelLower.contains("o1") || modelLower.contains("o3") {
            return 200000
        }

        // GPT-4o series (128K context)
        if modelLower.contains("gpt-4o") || modelLower.contains("gpt4o") {
            return 128000
        }

        // GPT-4-turbo (128K context)
        if modelLower.contains("gpt-4-turbo") || modelLower.contains("gpt4-turbo") {
            return 128000
        }

        // GPT-4-32k
        if modelLower.contains("gpt-4-32k") || modelLower.contains("gpt4-32k") {
            return 32768
        }

        // GPT-4 base (8K context)
        if modelLower.contains("gpt-4") || modelLower.contains("gpt4") {
            return 8192
        }

        // GPT-3.5 series
        if modelLower.contains("gpt-3.5-turbo-16k") || modelLower.contains("gpt3.5-turbo-16k") {
            return 16384
        }
        if modelLower.contains("gpt-3.5") || modelLower.contains("gpt3.5") {
            return 4096
        }

        // ==================== Anthropic Claude Models ====================

        // Claude 4.5 series (200K standard, 1M beta available)
        if modelLower.contains("claude-4.5") || modelLower.contains("claude-sonnet-4-5") ||
           modelLower.contains("claude-opus-4-5") || modelLower.contains("claude4.5") {
            return 200000
        }

        // Claude 4 series
        if modelLower.contains("claude-4") || modelLower.contains("claude4") ||
           modelLower.contains("claude-sonnet-4") || modelLower.contains("claude-opus-4") {
            return 200000
        }

        // Claude 3.5/3 series (200K context)
        if modelLower.contains("claude-3.5") || modelLower.contains("claude3.5") ||
           modelLower.contains("claude-3") || modelLower.contains("claude3") {
            return 200000
        }

        // Claude 2 series (100K context)
        if modelLower.contains("claude-2") || modelLower.contains("claude2") {
            return 100000
        }

        // Claude fallback
        if modelLower.contains("claude") {
            return 200000
        }

        // ==================== DeepSeek Models ====================

        // DeepSeek V3 / R1 / Coder-V2 (128K context)
        if modelLower.contains("deepseek-v3") || modelLower.contains("deepseek-r1") ||
           modelLower.contains("deepseek-coder-v2") || modelLower.contains("deepseek-coder") {
            return 128000
        }

        // DeepSeek V2 series
        if modelLower.contains("deepseek-v2") {
            return 128000
        }

        // DeepSeek generic (128K for newer models)
        if modelLower.contains("deepseek") {
            return 128000
        }

        // ==================== Google Gemini Models ====================

        // Gemini 2.0 Flash (1M context)
        if modelLower.contains("gemini-2.0") || modelLower.contains("gemini-2") ||
           modelLower.contains("gemini2") {
            return 1000000
        }

        // Gemini 1.5 Pro/Flash (128K standard, up to 1M/2M available)
        if modelLower.contains("gemini-1.5") || modelLower.contains("gemini1.5") {
            return 1000000
        }

        // Gemini Pro
        if modelLower.contains("gemini-pro") {
            return 128000
        }

        // Gemini fallback
        if modelLower.contains("gemini") {
            return 128000
        }

        // ==================== Qwen Models ====================

        // Qwen 1M series (1M context)
        if modelLower.contains("qwen") && modelLower.contains("1m") {
            return 1000000
        }

        // QwQ reasoning model (131K context)
        if modelLower.contains("qwq") {
            return 131072
        }

        // Qwen 2.5 Turbo / Long (1M context)
        if modelLower.contains("qwen2.5-turbo") || modelLower.contains("qwen-long") ||
           modelLower.contains("qwen-turbo") {
            return 1000000
        }

        // Qwen 2.5 series with extended context (128K)
        if modelLower.contains("qwen2.5") || modelLower.contains("qwen-2.5") {
            return 128000
        }

        // Qwen 2 series
        if modelLower.contains("qwen2") || modelLower.contains("qwen-2") {
            return 128000
        }

        // Qwen fallback (32K default)
        if modelLower.contains("qwen") {
            return 32000
        }

        // ==================== Meta Llama Models ====================

        // Llama 3.x series (128K context)
        if modelLower.contains("llama-3") || modelLower.contains("llama3") {
            return 128000
        }

        // Llama 2 series (4K context)
        if modelLower.contains("llama-2") || modelLower.contains("llama2") {
            return 4096
        }

        // Llama fallback
        if modelLower.contains("llama") {
            return 8192
        }

        // ==================== Mistral Models ====================

        // Mistral Large (128K context)
        if modelLower.contains("mistral-large") {
            return 128000
        }

        // Mixtral (32K context)
        if modelLower.contains("mixtral") {
            return 32768
        }

        // Mistral series (32K context)
        if modelLower.contains("mistral") {
            return 32768
        }

        // ==================== Other Models ====================

        // Yi series
        if modelLower.contains("yi-") {
            return 200000
        }

        // Cohere Command R
        if modelLower.contains("command-r") {
            return 128000
        }

        // Default fallback for unknown models
        return 8192
    }

    /// Calculate estimated token count from text
    /// Using approximate ratio: 1 token ≈ 4 characters for English, 1-2 characters for Chinese
    public static func estimateTokenCount(for text: String) -> Int {
        // Count Chinese characters
        let chinesePattern = "[\\u4e00-\\u9fff]"
        let chineseRegex = try? NSRegularExpression(pattern: chinesePattern, options: [])
        let chineseCount = chineseRegex?.numberOfMatches(in: text, options: [], range: NSRange(text.startIndex..., in: text)) ?? 0

        // Remaining characters (non-Chinese)
        let nonChineseCount = text.count - chineseCount

        // Estimate: Chinese ~1.5 tokens per char, English ~0.25 tokens per char
        let estimatedTokens = Int(Double(chineseCount) * 1.5 + Double(nonChineseCount) * 0.25)
        return max(estimatedTokens, 1)
    }

    /// Calculate the maximum number of messages that fit within context limit (80%)
    public func calculateMaxMessages(messagesText: String, requestedCount: Int) -> (actualCount: Int, truncated: Bool, reason: String?) {
        let contextSize = AIConfiguration.getContextSize(for: self.model)
        let maxContextUsage = Double(contextSize) * 0.8 // Use only 80% of context

        let estimatedTokens = AIConfiguration.estimateTokenCount(for: messagesText)
        let tokensPerMessage = max(1, estimatedTokens / max(1, requestedCount))

        if Double(estimatedTokens) <= maxContextUsage {
            return (requestedCount, false, nil)
        }

        // Calculate how many messages we can fit
        let maxMessages = Int(maxContextUsage / Double(tokensPerMessage))
        let actualCount = min(max(1, maxMessages), requestedCount)
        let reason = "Context size exceeded, only fetched \(actualCount) messages (model context: \(contextSize) tokens)"

        return (actualCount, true, reason)
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
