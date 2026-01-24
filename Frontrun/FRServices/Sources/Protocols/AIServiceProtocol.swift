import SwiftSignalKit

public protocol AIServiceProtocol {
    func sendMessage(messages: [AIMessage], stream: Bool) -> Signal<AIStreamChunk, AIError>
}
