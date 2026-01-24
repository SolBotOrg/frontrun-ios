import Foundation
import SwiftSignalKit

public enum AIError: Error {
    case invalidConfiguration
    case networkError(Error)
    case invalidResponse
    case apiError(String)
    case decodingError
}

public struct AIMessage: Codable {
    public let role: String
    public let content: String

    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

public struct AIStreamChunk {
    public let content: String
    public let isComplete: Bool

    public init(content: String, isComplete: Bool) {
        self.content = content
        self.isComplete = isComplete
    }
}

private class StreamingDelegate: NSObject, URLSessionDataDelegate {
    let subscriber: Subscriber<AIStreamChunk, AIError>
    let configuration: AIConfiguration
    var receivedData = Data()

    init(subscriber: Subscriber<AIStreamChunk, AIError>, configuration: AIConfiguration) {
        self.subscriber = subscriber
        self.configuration = configuration
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        receivedData.append(data)

        guard let dataString = String(data: data, encoding: .utf8) else {
            return
        }

        let lines = dataString.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.isEmpty || trimmed == "data: [DONE]" {
                continue
            }

            if trimmed.hasPrefix("data: ") {
                let jsonString = String(trimmed.dropFirst(6))

                guard let jsonData = jsonString.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                    #if DEBUG
                    print("[AIService] Failed to parse JSON: \(jsonString.prefix(100))")
                    #endif
                    continue
                }

                if let content = extractContentFromStreamChunk(json: json, configuration: configuration) {
                    subscriber.putNext(AIStreamChunk(content: content, isComplete: false))
                }
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        defer {
            // Clean up session to prevent memory leak
            session.finishTasksAndInvalidate()
            receivedData = Data()
        }

        if let error = error {
            subscriber.putError(.networkError(error))
            return
        }

        // Check if we received any data at all
        if receivedData.isEmpty {
            subscriber.putError(.invalidResponse)
            return
        }

        // Check HTTP status code
        if let httpResponse = task.response as? HTTPURLResponse {
            if httpResponse.statusCode != 200 {
                // Try to parse error message from response
                if let errorString = String(data: receivedData, encoding: .utf8),
                   let jsonData = errorString.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                   let error = json["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    subscriber.putError(.apiError(message))
                } else {
                    subscriber.putError(.apiError("HTTP \(httpResponse.statusCode)"))
                }
                return
            }
        }

        subscriber.putNext(AIStreamChunk(content: "", isComplete: true))
        subscriber.putCompletion()
    }

    private func extractContentFromStreamChunk(json: [String: Any], configuration: AIConfiguration) -> String? {
        switch configuration.provider {
        case .openai, .custom:
            if let choices = json["choices"] as? [[String: Any]],
               let first = choices.first,
               let delta = first["delta"] as? [String: Any],
               let content = delta["content"] as? String {
                return content
            }
        case .anthropic:
            if let type = json["type"] as? String, type == "content_block_delta",
               let delta = json["delta"] as? [String: Any],
               let text = delta["text"] as? String {
                return text
            }
        }
        return nil
    }
}

public struct AIModel {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

public final class AIService: AIServiceProtocol {
    private let configuration: AIConfiguration

    public init(configuration: AIConfiguration) {
        self.configuration = configuration
    }

    public static func fetchModels(baseURL: String, apiKey: String, provider: AIProvider) -> Signal<[AIModel], AIError> {
        return Signal { subscriber in
            var urlString = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)

            // Remove trailing slash
            if urlString.hasSuffix("/") {
                urlString = String(urlString.dropLast())
            }

            // Build the models endpoint URL
            switch provider {
            case .openai, .custom:
                // Remove /chat/completions if present
                if urlString.hasSuffix("/chat/completions") {
                    urlString = String(urlString.dropLast("/chat/completions".count))
                }
                // Add /v1 if not present
                if !urlString.contains("/v1") {
                    urlString += "/v1"
                }
                urlString += "/models"
            case .anthropic:
                // Anthropic doesn't have a public models endpoint, return empty
                subscriber.putNext([])
                subscriber.putCompletion()
                return EmptyDisposable
            }

            guard let url = URL(string: urlString) else {
                subscriber.putError(.invalidConfiguration)
                return EmptyDisposable
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    subscriber.putError(.networkError(error))
                    return
                }

                guard let data = data else {
                    subscriber.putError(.invalidResponse)
                    return
                }

                // Check HTTP status code
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    if let errorString = String(data: data, encoding: .utf8),
                       let jsonData = errorString.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                       let error = json["error"] as? [String: Any],
                       let message = error["message"] as? String {
                        subscriber.putError(.apiError(message))
                    } else {
                        subscriber.putError(.apiError("HTTP \(httpResponse.statusCode)"))
                    }
                    return
                }

                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let dataArray = json["data"] as? [[String: Any]] else {
                    subscriber.putError(.decodingError)
                    return
                }

                var models: [AIModel] = []
                for item in dataArray {
                    if let id = item["id"] as? String {
                        // Use id as name, or get owned_by for more context
                        let ownedBy = item["owned_by"] as? String ?? ""
                        let displayName = ownedBy.isEmpty ? id : "\(id) (\(ownedBy))"
                        models.append(AIModel(id: id, name: displayName))
                    }
                }

                // Sort models alphabetically
                models.sort { $0.id < $1.id }

                subscriber.putNext(models)
                subscriber.putCompletion()
            }

            task.resume()

            return ActionDisposable {
                task.cancel()
            }
        }
    }

    public func sendMessage(
        messages: [AIMessage],
        stream: Bool = true
    ) -> Signal<AIStreamChunk, AIError> {
        guard configuration.isValid && configuration.enabled else {
            return .fail(.invalidConfiguration)
        }

        return Signal { subscriber in
            let task = self.performRequest(messages: messages, stream: stream, subscriber: subscriber)

            return ActionDisposable {
                task?.cancel()
            }
        }
    }

    private func performRequest(
        messages: [AIMessage],
        stream: Bool,
        subscriber: Subscriber<AIStreamChunk, AIError>
    ) -> URLSessionDataTask? {
        guard let url = URL(string: configuration.buildEndpointURL()) else {
            subscriber.putError(.invalidConfiguration)
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        switch configuration.provider {
        case .openai:
            request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        case .anthropic:
            request.setValue(configuration.apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        case .custom:
            request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        }

        let body = createRequestBody(messages: messages, stream: stream)
        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
            subscriber.putError(.invalidConfiguration)
            return nil
        }
        request.httpBody = httpBody

        if stream {
            return performStreamingRequest(request: request, subscriber: subscriber)
        } else {
            return performNormalRequest(request: request, subscriber: subscriber)
        }
    }

    private func performStreamingRequest(
        request: URLRequest,
        subscriber: Subscriber<AIStreamChunk, AIError>
    ) -> URLSessionDataTask {
        let delegate = StreamingDelegate(subscriber: subscriber, configuration: configuration)
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        let task = session.dataTask(with: request)
        task.resume()
        return task
    }

    private func performNormalRequest(
        request: URLRequest,
        subscriber: Subscriber<AIStreamChunk, AIError>
    ) -> URLSessionDataTask {
        let session = URLSession.shared
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                subscriber.putError(.networkError(error))
                return
            }

            guard let data = data else {
                subscriber.putError(.invalidResponse)
                return
            }

            do {
                let content = try self.parseNormalResponse(data: data)
                subscriber.putNext(AIStreamChunk(content: content, isComplete: true))
                subscriber.putCompletion()
            } catch let error as AIError {
                subscriber.putError(error)
            } catch {
                subscriber.putError(.decodingError)
            }
        }

        task.resume()
        return task
    }

    private func parseNormalResponse(data: Data) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIError.decodingError
        }

        return try extractContentFromNormalResponse(json: json)
    }

    private func extractContentFromNormalResponse(json: [String: Any]) throws -> String {
        switch configuration.provider {
        case .openai, .custom:
            if let choices = json["choices"] as? [[String: Any]],
               let first = choices.first,
               let message = first["message"] as? [String: Any],
               let content = message["content"] as? String {
                return content
            }
        case .anthropic:
            if let content = json["content"] as? [[String: Any]],
               let first = content.first,
               let text = first["text"] as? String {
                return text
            }
        }

        if let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            throw AIError.apiError(message)
        }

        throw AIError.decodingError
    }

    private func createRequestBody(messages: [AIMessage], stream: Bool) -> [String: Any] {
        switch configuration.provider {
        case .openai, .custom:
            return [
                "model": configuration.model,
                "messages": messages.map { ["role": $0.role, "content": $0.content] },
                "stream": stream
            ]
        case .anthropic:
            var anthropicMessages: [[String: String]] = []

            for message in messages where message.role != "system" {
                anthropicMessages.append(["role": message.role, "content": message.content])
            }

            var body: [String: Any] = [
                "model": configuration.model,
                "messages": anthropicMessages,
                "max_tokens": 4096,
                "stream": stream
            ]

            if let systemMessage = messages.first(where: { $0.role == "system" }) {
                body["system"] = systemMessage.content
            }

            return body
        }
    }
}
