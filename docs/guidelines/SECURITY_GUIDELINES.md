# Security Guidelines for Frontrun

> Security principles and requirements for wallet and trading features.

## Core Security Principles

### 1. Keys Never Leave Secure Storage

**Principle:** Private keys and seed phrases must never exist in memory longer than necessary.

**Requirements:**
- Store keys in iOS Keychain with Secure Enclave protection
- Zero out key data from memory immediately after use
- Never log, print, or transmit key material
- Never store keys in UserDefaults, files, or any non-secure storage

```swift
// CORRECT: Use Keychain with Secure Enclave
let access = SecAccessControlCreateWithFlags(
    nil,
    kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
    [.privateKeyUsage, .biometryCurrentSet],
    nil
)

// CORRECT: Zero out after use
defer {
    privateKeyData.resetBytes(in: 0..<privateKeyData.count)
}

// WRONG: Never do this
print("Key: \(privateKey)")  // ❌
UserDefaults.standard.set(privateKey, forKey: "key")  // ❌
logger.debug("Signing with \(privateKey)")  // ❌
```

### 2. Authentication Before Sensitive Actions

**Principle:** Require biometric or PIN authentication before any action that could result in loss of funds.

**Requires Authentication:**
- Transaction signing
- Viewing seed phrase
- Exporting private key
- Deleting wallet
- Changing security settings

**Does NOT Require Authentication:**
- Viewing public address
- Viewing portfolio (read-only)
- Viewing transaction history
- Copying address to clipboard

### 3. User Confirmation Before Irreversible Actions

**Principle:** Show clear confirmation before any action that cannot be undone.

**Requires Confirmation:**
- Submitting transactions (show full details: amount, fees, recipient)
- Deleting wallet
- Clearing data

**Confirmation UI Must Show:**
- What will happen
- Any fees involved
- Cannot be undone (if applicable)
- Require explicit action (not auto-dismiss)

### 4. Validate All External Data

**Principle:** Never trust data from external sources without validation.

**Validate:**
- Token metadata from APIs (could be spoofed)
- Transaction parameters from deep links
- Price data before displaying to user
- Any data that influences transaction construction

```swift
// CORRECT: Validate token address format
guard ContractAddressDetector.isValidAddress(tokenAddress) else {
    throw TokenError.invalidAddress
}

// CORRECT: Validate amount is within expected range
guard amount > 0 && amount <= userBalance else {
    throw TradeError.invalidAmount
}

// WRONG: Trust external data directly
let tx = Transaction(to: deepLinkParams["to"]!)  // ❌
```

---

## Key Storage Architecture

### Keychain Configuration

```swift
// Service name for Frontrun wallet keys
private let serviceName = "com.frontrun.wallet"

// Key types stored
enum KeyType: String {
    case privateKey = "pk"      // Private key (encrypted)
    case seedPhrase = "seed"    // Seed phrase (encrypted)
}

// Access control: Biometric + device lock
let accessControl = SecAccessControlCreateWithFlags(
    nil,
    kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
    [.privateKeyUsage, .biometryCurrentSet],
    nil
)
```

### What Goes Where

| Data | Storage | Protection |
|------|---------|------------|
| Private key | Keychain + Secure Enclave | Biometric required |
| Seed phrase | Keychain + Secure Enclave | Biometric required |
| Wallet metadata (name, address) | UserDefaults | None (public info) |
| Transaction history | UserDefaults/Cache | None (public info) |
| User preferences | UserDefaults | None |

---

## Transaction Security

### Pre-Transaction Validation

Before signing any transaction:

1. **Verify amount:** Within user's balance
2. **Verify recipient:** Valid address format
3. **Verify fees:** Within expected range
4. **Check token:** Not flagged as scam/honeypot
5. **Staleness check:** Price data is recent

```swift
func validateTransaction(_ config: QuickBuyConfig) -> Result<Void, ValidationError> {
    // 1. Check balance
    guard config.amount <= currentBalance else {
        return .failure(.insufficientBalance)
    }

    // 2. Check token safety
    if config.token.riskLevel == .danger {
        return .failure(.dangerousToken)
    }

    // 3. Check price freshness
    guard config.priceTimestamp.timeIntervalSinceNow > -60 else {
        return .failure(.stalePriceData)
    }

    return .success(())
}
```

### Transaction Confirmation UI

Must display:
- Token name and symbol
- Amount being traded
- Estimated value in USD
- Network fee
- Slippage tolerance
- Total cost
- Clear "Confirm" and "Cancel" buttons

### Post-Transaction Handling

- Show pending state immediately
- Poll for confirmation (with timeout)
- Show success with transaction hash
- On failure, show clear error message
- Provide "View on Explorer" link

---

## Token Safety

### Risk Levels

| Level | Criteria | UI Treatment |
|-------|----------|--------------|
| `safe` | Verified, high liquidity, established | Green badge |
| `unknown` | Not verified, limited data | Yellow warning |
| `warning` | Low liquidity, new token | Orange warning + confirm |
| `danger` | Known scam, honeypot | Red warning, block by default |

### Safety Check Sources

Integrate with token safety APIs:
- GoPlus Security API
- RugCheck
- Jupiter strict list

### Warning Dialogs

For `warning` tokens:
```
⚠️ Unverified Token

This token has limited history and may be risky.
- Low liquidity
- Not on verified lists

Do you want to proceed anyway?

[Cancel]  [I understand, proceed]
```

For `danger` tokens:
```
🚫 Dangerous Token

This token has been flagged as potentially harmful:
- Reported as honeypot
- Cannot sell after buying

Trading is blocked for your protection.

[Dismiss]
```

---

## Network Security

### RPC Endpoint Security

- Use HTTPS only
- Implement certificate pinning for critical endpoints
- Have fallback endpoints for reliability
- Don't expose RPC URLs in logs

### API Key Protection

- Never hardcode API keys in source
- Store in secure configuration (not UserDefaults)
- Rotate keys periodically
- Use environment-specific keys (dev/prod)

---

## Data Privacy

### What We Collect

Be explicit about data collection:
- Wallet addresses (public)
- Transaction history (public on-chain)
- Usage analytics (optional, anonymized)

### What We Never Collect

- Private keys (never leave device)
- Seed phrases (never leave device)
- Chat content (stays in Telegram)
- Personal identification

### Data Storage

- All sensitive data encrypted at rest
- Use iOS Data Protection (Complete protection class)
- Implement secure deletion when user requests

---

## Audit Checklist

Before shipping any wallet/trading feature:

- [ ] Private keys stored in Keychain with Secure Enclave
- [ ] Biometric required for transaction signing
- [ ] Keys zeroed from memory after use
- [ ] No key material in logs
- [ ] Transaction confirmation shows all details
- [ ] Token safety warnings implemented
- [ ] Input validation on all external data
- [ ] Error handling doesn't leak sensitive info
- [ ] HTTPS only for all network calls
- [ ] Tested with malformed/malicious inputs
