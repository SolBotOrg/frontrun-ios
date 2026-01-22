import Foundation
import SwiftSignalKit

// MARK: - Token Info Model

public struct DexTokenInfo: Codable, Equatable {
    public let address: String
    public let name: String
    public let symbol: String
    public let priceUsd: String?
    public let priceChange24h: Double?
    public let volume24h: Double?
    public let marketCap: Double?
    public let fdv: Double?
    public let imageUrl: String?
    public let chainId: String
    public let dexId: String?
    public let pairAddress: String?
    
    public init(
        address: String,
        name: String,
        symbol: String,
        priceUsd: String? = nil,
        priceChange24h: Double? = nil,
        volume24h: Double? = nil,
        marketCap: Double? = nil,
        fdv: Double? = nil,
        imageUrl: String? = nil,
        chainId: String,
        dexId: String? = nil,
        pairAddress: String? = nil
    ) {
        self.address = address
        self.name = name
        self.symbol = symbol
        self.priceUsd = priceUsd
        self.priceChange24h = priceChange24h
        self.volume24h = volume24h
        self.marketCap = marketCap
        self.fdv = fdv
        self.imageUrl = imageUrl
        self.chainId = chainId
        self.dexId = dexId
        self.pairAddress = pairAddress
    }
    
    // MARK: - Explorer URLs
    
    public func getExplorerUrl() -> String? {
        let addr = self.address
        switch chainId.lowercased() {
        case "ethereum", "eth":
            return "https://etherscan.io/token/\(addr)"
        case "bsc", "binance":
            return "https://bscscan.com/token/\(addr)"
        case "solana":
            return "https://solscan.io/token/\(addr)"
        case "arbitrum":
            return "https://arbiscan.io/token/\(addr)"
        case "base":
            return "https://basescan.org/token/\(addr)"
        case "polygon":
            return "https://polygonscan.com/token/\(addr)"
        case "avalanche", "avax":
            return "https://snowtrace.io/token/\(addr)"
        case "optimism":
            return "https://optimistic.etherscan.io/token/\(addr)"
        case "fantom", "ftm":
            return "https://ftmscan.com/token/\(addr)"
        case "cronos":
            return "https://cronoscan.com/token/\(addr)"
        default:
            // Fallback to DexScreener
            return "https://dexscreener.com/\(chainId)/\(addr)"
        }
    }
    
    public func getDexScreenerUrl() -> String {
        return "https://dexscreener.com/\(chainId)/\(pairAddress ?? address)"
    }
    
    // MARK: - Formatted Values
    
    public var formattedPrice: String {
        guard let priceStr = priceUsd, let price = Double(priceStr) else {
            return "N/A"
        }
        if price < 0.00001 {
            return String(format: "$%.8f", price)
        } else if price < 0.01 {
            return String(format: "$%.6f", price)
        } else if price < 1 {
            return String(format: "$%.4f", price)
        } else {
            return String(format: "$%.2f", price)
        }
    }
    
    public var formattedPriceChange: String {
        guard let change = priceChange24h else { return "N/A" }
        let sign = change >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", change))%"
    }
    
    public var isPriceUp: Bool {
        return (priceChange24h ?? 0) >= 0
    }
    
    public var formattedMarketCap: String {
        return formatLargeNumber(marketCap)
    }
    
    public var formattedVolume: String {
        return formatLargeNumber(volume24h)
    }
    
    public var formattedFdv: String {
        return formatLargeNumber(fdv)
    }
    
    private func formatLargeNumber(_ value: Double?) -> String {
        guard let value = value, value > 0 else { return "N/A" }
        if value >= 1_000_000_000 {
            return String(format: "$%.2fB", value / 1_000_000_000)
        } else if value >= 1_000_000 {
            return String(format: "$%.2fM", value / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "$%.2fK", value / 1_000)
        } else {
            return String(format: "$%.2f", value)
        }
    }
}

// MARK: - DexScreener Service

public final class DexScreenerService {
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

// MARK: - Chain Detection Helpers

public extension DexScreenerService {
    
    /// Detect chain type from address format
    static func detectChainType(address: String) -> String? {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // EVM address: 0x + 40 hex chars = 42 total
        if trimmed.hasPrefix("0x") && trimmed.count == 42 {
            return "evm"
        }
        
        // Solana address: base58, typically 32-44 chars
        if trimmed.count >= 32 && trimmed.count <= 44 {
            let base58Chars = CharacterSet(charactersIn: "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")
            if trimmed.unicodeScalars.allSatisfy({ base58Chars.contains($0) }) {
                return "solana"
            }
        }
        
        return nil
    }
    
    /// Check if string looks like a token address
    static func isValidTokenAddress(_ string: String) -> Bool {
        return detectChainType(address: string) != nil
    }
}
