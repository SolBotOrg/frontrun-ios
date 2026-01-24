import Foundation

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
        // Validate address before URL construction
        guard ChainDetection.isValidTokenAddress(address) else { return nil }

        // URL-encode the address for safe interpolation
        guard let encodedAddr = address.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            return nil
        }

        switch chainId.lowercased() {
        case "ethereum", "eth":
            return "https://etherscan.io/token/\(encodedAddr)"
        case "bsc", "binance":
            return "https://bscscan.com/token/\(encodedAddr)"
        case "solana":
            return "https://solscan.io/token/\(encodedAddr)"
        case "arbitrum":
            return "https://arbiscan.io/token/\(encodedAddr)"
        case "base":
            return "https://basescan.org/token/\(encodedAddr)"
        case "polygon":
            return "https://polygonscan.com/token/\(encodedAddr)"
        case "avalanche", "avax":
            return "https://snowtrace.io/token/\(encodedAddr)"
        case "optimism":
            return "https://optimistic.etherscan.io/token/\(encodedAddr)"
        case "fantom", "ftm":
            return "https://ftmscan.com/token/\(encodedAddr)"
        case "cronos":
            return "https://cronoscan.com/token/\(encodedAddr)"
        default:
            // Fallback to DexScreener - also encode chainId
            guard let encodedChain = chainId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
                return nil
            }
            return "https://dexscreener.com/\(encodedChain)/\(encodedAddr)"
        }
    }

    public func getDexScreenerUrl() -> String? {
        // URL-encode parameters for safe interpolation
        guard let encodedChain = chainId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            return nil
        }
        let targetAddress = pairAddress ?? address
        guard let encodedAddr = targetAddress.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            return nil
        }
        return "https://dexscreener.com/\(encodedChain)/\(encodedAddr)"
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

// MARK: - Chain Detection Helpers

public enum ChainDetection {

    /// Detect chain type from address format
    public static func detectChainType(address: String) -> String? {
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
    public static func isValidTokenAddress(_ string: String) -> Bool {
        return detectChainType(address: string) != nil
    }
}
