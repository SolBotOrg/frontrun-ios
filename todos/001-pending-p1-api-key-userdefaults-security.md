---
status: completed
priority: p1
issue_id: "001"
tags: [code-review, security, pr-15]
dependencies: []
---

# API Keys Stored in UserDefaults (Security Vulnerability)

## Problem Statement

API keys for AI providers (OpenAI, Anthropic, custom endpoints) are stored in `UserDefaults`, which is **not encrypted** and can be extracted from device backups or accessed on jailbroken devices. This violates Apple's security best practices and the frontrun-eng security requirements.

Per frontrun-eng skill:
> **Never:** log keys, store in UserDefaults, keep in memory

## Findings

**File:** `Frontrun/FRServices/Sources/AIConfiguration.swift`
**Lines:** 539-569

```swift
// TODO: Migrate API key storage to Keychain for security (separate ticket)
public final class AIConfigurationStorage {
    private let userDefaultsKey = "telegram.ai.configuration"

    public func saveConfiguration(_ config: AIConfiguration) {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
}
```

**Impact:**
- API keys can be extracted from unencrypted iTunes/Finder backups
- On jailbroken devices, any process can read UserDefaults plists
- Violates OWASP Mobile Top 10: M2 - Insecure Data Storage

## Proposed Solutions

### Option 1: Keychain with Secure Enclave (Recommended)
- **Pros:** Maximum security, hardware-backed protection, biometric support
- **Cons:** More complex implementation, requires migration logic
- **Effort:** Medium (4-6 hours)
- **Risk:** Low - well-documented iOS pattern

```swift
import Security

public final class SecureAIConfigurationStorage {
    private let keychainKey = "com.frontrun.ai.configuration"

    func saveAPIKey(_ key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecValueData as String: key.data(using: .utf8)!,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.saveFailed }
    }
}
```

### Option 2: Keychain Simple (Wrapper Library)
- **Pros:** Faster implementation using KeychainAccess or similar
- **Cons:** Additional dependency
- **Effort:** Small (2-3 hours)
- **Risk:** Low

### Option 3: Store Non-Sensitive Config Separately
- **Pros:** Keep provider/model in UserDefaults, only move API key to Keychain
- **Cons:** Split storage, more complex retrieval
- **Effort:** Small (2-3 hours)
- **Risk:** Low

## Recommended Action

**Option 1** - Use native Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` for API key storage. Create migration path from existing UserDefaults storage.

## Technical Details

**Affected files:**
- `Frontrun/FRServices/Sources/AIConfiguration.swift` (lines 539-569)

**Components affected:**
- AIConfigurationStorage singleton
- All callers of getConfiguration/saveConfiguration

**Migration required:**
- Check for existing UserDefaults data on first launch
- Migrate API key to Keychain
- Clear old UserDefaults entry
- Update configuration struct to not include apiKey in Codable

## Acceptance Criteria

- [x] API keys are stored in iOS Keychain, not UserDefaults
- [x] Keychain access uses `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
- [x] Migration from UserDefaults works for existing users
- [x] Old UserDefaults API key data is deleted after migration
- [x] Build succeeds and AI features work correctly

## Work Log

| Date | Action | Learnings |
|------|--------|-----------|
| 2026-01-24 | Identified in PR #15 code review | Security agents flagged UserDefaults storage |

## Resources

- PR: https://github.com/SolBotOrg/frontrun-ios/pull/15
- Apple Keychain Services: https://developer.apple.com/documentation/security/keychain_services
- OWASP Mobile Security: https://owasp.org/www-project-mobile-top-10/
