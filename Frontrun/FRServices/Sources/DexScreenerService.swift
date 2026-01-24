import Foundation
import SwiftSignalKit
import FRModels

// MARK: - DexScreener Service

public final class DexScreenerService: DexScreenerServiceProtocol {
    public static let shared = DexScreenerService()

    private var cache: [String: DexTokenInfo] = [:]
    private var pendingRequests: [String: Signal<DexTokenInfo?, NoError>] = [:]
    private let queue = DispatchQueue(label: "com.dexscreener.cache", attributes: .concurrent)

    private let baseUrl = "https://api.dexscreener.com/latest/dex/tokens"

    private init() {}

    // MARK: - Public API

    public func fetchTokenInfo(address: String) -> Signal<DexTokenInfo?, NoError> {
        let normalizedAddress = address.lowercased()

        // Check cache first
        var cachedInfo: DexTokenInfo?
        queue.sync {
            cachedInfo = cache[normalizedAddress]
        }
        if let cached = cachedInfo {
            return .single(cached)
        }

        // Check if request is already pending
        var pending: Signal<DexTokenInfo?, NoError>?
        queue.sync {
            pending = pendingRequests[normalizedAddress]
        }
        if let pendingSignal = pending {
            return pendingSignal
        }

        // Create new request
        let signal = self.makeRequest(address: normalizedAddress)
            |> afterNext { [weak self] info in
                guard let self = self else { return }
                self.queue.async(flags: .barrier) {
                    if let info = info {
                        self.cache[normalizedAddress] = info
                    }
                    self.pendingRequests.removeValue(forKey: normalizedAddress)
                }
            }

        queue.async(flags: .barrier) {
            self.pendingRequests[normalizedAddress] = signal
        }

        return signal
    }

    public func fetchMultipleTokenInfo(addresses: [String]) -> Signal<[String: DexTokenInfo], NoError> {
        let signals = addresses.map { address -> Signal<(String, DexTokenInfo?), NoError> in
            return fetchTokenInfo(address: address)
                |> map { info in (address, info) }
        }

        return combineLatest(signals)
            |> map { results in
                var dict: [String: DexTokenInfo] = [:]
                for (address, info) in results {
                    if let info = info {
                        dict[address.lowercased()] = info
                    }
                }
                return dict
            }
    }

    public func clearCache() {
        queue.async(flags: .barrier) {
            self.cache.removeAll()
        }
    }

    // MARK: - Private Methods

    private func makeRequest(address: String) -> Signal<DexTokenInfo?, NoError> {
        return Signal { subscriber in
            guard let url = URL(string: "\(self.baseUrl)/\(address)") else {
                subscriber.putNext(nil)
                subscriber.putCompletion()
                return EmptyDisposable
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 10

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("[DexScreener] Network error for \(address): \(error.localizedDescription)")
                    subscriber.putNext(nil)
                    subscriber.putCompletion()
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    subscriber.putNext(nil)
                    subscriber.putCompletion()
                    return
                }

                guard httpResponse.statusCode == 200, let data = data else {
                    print("[DexScreener] HTTP error \(httpResponse.statusCode) for \(address)")
                    subscriber.putNext(nil)
                    subscriber.putCompletion()
                    return
                }

                do {
                    let tokenInfo = try self.parseResponse(data: data, address: address)
                    subscriber.putNext(tokenInfo)
                } catch {
                    print("[DexScreener] Parse error for \(address): \(error)")
                    subscriber.putNext(nil)
                }
                subscriber.putCompletion()
            }

            task.resume()

            return ActionDisposable {
                task.cancel()
            }
        }
    }

    private func parseResponse(data: Data, address: String) throws -> DexTokenInfo? {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        guard let pairs = json["pairs"] as? [[String: Any]], let firstPair = pairs.first else {
            return nil
        }

        // Extract base token info
        guard let baseToken = firstPair["baseToken"] as? [String: Any],
              let tokenAddress = baseToken["address"] as? String,
              let name = baseToken["name"] as? String,
              let symbol = baseToken["symbol"] as? String else {
            return nil
        }

        // Extract chain and dex info
        let chainId = firstPair["chainId"] as? String ?? "unknown"
        let dexId = firstPair["dexId"] as? String
        let pairAddress = firstPair["pairAddress"] as? String

        // Extract price info
        let priceUsd = firstPair["priceUsd"] as? String

        // Extract price change
        var priceChange24h: Double? = nil
        if let priceChange = firstPair["priceChange"] as? [String: Any] {
            if let h24 = priceChange["h24"] as? Double {
                priceChange24h = h24
            } else if let h24String = priceChange["h24"] as? String, let h24 = Double(h24String) {
                priceChange24h = h24
            }
        }

        // Extract volume
        var volume24h: Double? = nil
        if let volume = firstPair["volume"] as? [String: Any] {
            if let h24 = volume["h24"] as? Double {
                volume24h = h24
            } else if let h24String = volume["h24"] as? String, let h24 = Double(h24String) {
                volume24h = h24
            }
        }

        // Extract market cap and FDV
        var marketCap: Double? = nil
        if let mc = firstPair["marketCap"] as? Double {
            marketCap = mc
        } else if let mcString = firstPair["marketCap"] as? String, let mc = Double(mcString) {
            marketCap = mc
        }

        var fdv: Double? = nil
        if let f = firstPair["fdv"] as? Double {
            fdv = f
        } else if let fString = firstPair["fdv"] as? String, let f = Double(fString) {
            fdv = f
        }

        // Extract image URL - try multiple paths
        var imageUrl: String? = nil
        // Try pair.info.imageUrl
        if let info = firstPair["info"] as? [String: Any],
           let imageUrlStr = info["imageUrl"] as? String {
            imageUrl = imageUrlStr
        }
        // Try baseToken.info.imageUrl
        if imageUrl == nil, let tokenInfo = baseToken["info"] as? [String: Any],
           let imageUrlStr = tokenInfo["imageUrl"] as? String {
            imageUrl = imageUrlStr
        }
        // Try pair.info.header for header image
        if imageUrl == nil, let info = firstPair["info"] as? [String: Any],
           let header = info["header"] as? String {
            imageUrl = header
        }

        return DexTokenInfo(
            address: tokenAddress,
            name: name,
            symbol: symbol,
            priceUsd: priceUsd,
            priceChange24h: priceChange24h,
            volume24h: volume24h,
            marketCap: marketCap,
            fdv: fdv,
            imageUrl: imageUrl,
            chainId: chainId,
            dexId: dexId,
            pairAddress: pairAddress
        )
    }
}
