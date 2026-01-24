import SwiftSignalKit
import FRModels

public protocol DexScreenerServiceProtocol {
    func fetchTokenInfo(address: String) -> Signal<DexTokenInfo?, NoError>
    func fetchMultipleTokenInfo(addresses: [String]) -> Signal<[String: DexTokenInfo], NoError>
    func clearCache()
}
