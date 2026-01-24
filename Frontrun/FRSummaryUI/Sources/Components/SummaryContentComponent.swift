import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import AccountContext
import ComponentFlow
import ViewControllerComponent
import MultilineTextComponent
import Markdown
import GlassBarButtonComponent
import BundleIconComponent
import AvatarNode
import FRServices
import FRModels

// MARK: - FRSummaryContentComponent

final class FRSummaryContentComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let peerId: PeerId
    let theme: PresentationTheme
    let summaryTitle: String
    let summaryText: String
    let truncationNotice: String?
    let messageIdMap: [Int32: MessageId]
    let messagePeerMap: [Int32: Peer]
    let isLoading: Bool
    let maxHeight: CGFloat
    let originalMessagesText: String
    let dismiss: () -> Void
    let navigateToMessage: (MessageId) -> Void
    let openSettings: () -> Void
    let showTokenDetail: (String, DexTokenInfo?, CGRect) -> Void

    init(context: AccountContext, peerId: PeerId, theme: PresentationTheme, summaryTitle: String, summaryText: String, truncationNotice: String?, messageIdMap: [Int32: MessageId], messagePeerMap: [Int32: Peer], isLoading: Bool, maxHeight: CGFloat, originalMessagesText: String, dismiss: @escaping () -> Void, navigateToMessage: @escaping (MessageId) -> Void, openSettings: @escaping () -> Void, showTokenDetail: @escaping (String, DexTokenInfo?, CGRect) -> Void) {
        self.context = context
        self.peerId = peerId
        self.theme = theme
        self.summaryTitle = summaryTitle
        self.summaryText = summaryText
        self.truncationNotice = truncationNotice
        self.messageIdMap = messageIdMap
        self.messagePeerMap = messagePeerMap
        self.isLoading = isLoading
        self.maxHeight = maxHeight
        self.originalMessagesText = originalMessagesText
        self.dismiss = dismiss
        self.navigateToMessage = navigateToMessage
        self.openSettings = openSettings
        self.showTokenDetail = showTokenDetail
    }

    static func ==(lhs: FRSummaryContentComponent, rhs: FRSummaryContentComponent) -> Bool {
        if lhs.context !== rhs.context { return false }
        if lhs.peerId != rhs.peerId { return false }
        if lhs.theme !== rhs.theme { return false }
        if lhs.summaryTitle != rhs.summaryTitle { return false }
        if lhs.summaryText != rhs.summaryText { return false }
        if lhs.truncationNotice != rhs.truncationNotice { return false }
        if lhs.messageIdMap != rhs.messageIdMap { return false }
        if lhs.isLoading != rhs.isLoading { return false }
        if lhs.maxHeight != rhs.maxHeight { return false }
        return true
    }

    final class View: UIView {
        private let scrollView: UIScrollView
        private let closeButton = ComponentView<Empty>()
        private let settingsButton = ComponentView<Empty>()
        private let titleLabel = ComponentView<Empty>()
        private let summaryTitleLabel = ComponentView<Empty>()
        private let truncationLabel = ComponentView<Empty>()
        private let summaryTextView: UITextView
        private let activityIndicator: UIActivityIndicatorView
        private var currentText: String = ""

        private var dismissAction: (() -> Void)?
        private var navigateToMessageAction: ((MessageId) -> Void)?
        private var openSettingsAction: (() -> Void)?
        private var showTokenDetailAction: ((String, DexTokenInfo?, CGRect) -> Void)?
        private var messageIdMap: [Int32: MessageId] = [:]
        private var messagePeerMap: [Int32: Peer] = [:]
        private weak var context: AccountContext?
        private var originalMessagesText: String = ""

        private let userNavigationKey = NSAttributedString.Key("TelegramUserNavigation")
        private let tokenNavigationKey = NSAttributedString.Key("TelegramTokenNavigation")

        private var avatarCache: [EnginePeer.Id: UIImage] = [:]
        private var avatarLoadingDisposables: [EnginePeer.Id: Disposable] = [:]

        private var tokenInfoCache: [String: DexTokenInfo] = [:]
        private var tokenLogoCache: [String: UIImage] = [:]
        private var tokenInfoDisposable: Disposable?
        private var tokenLogoDisposables: [String: Disposable] = [:]

        override init(frame: CGRect) {
            self.scrollView = UIScrollView()
            self.scrollView.showsVerticalScrollIndicator = true
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.alwaysBounceVertical = true

            self.summaryTextView = UITextView()
            self.summaryTextView.isEditable = false
            self.summaryTextView.isScrollEnabled = false
            self.summaryTextView.backgroundColor = .clear
            self.summaryTextView.textContainerInset = .zero
            self.summaryTextView.textContainer.lineFragmentPadding = 0
            self.summaryTextView.linkTextAttributes = [:]

            if #available(iOS 13.0, *) {
                self.activityIndicator = UIActivityIndicatorView(style: .medium)
                self.activityIndicator.color = .white
            } else {
                self.activityIndicator = UIActivityIndicatorView(style: .white)
            }

            super.init(frame: frame)

            self.addSubview(self.scrollView)
            self.scrollView.addSubview(self.activityIndicator)
            self.scrollView.addSubview(self.summaryTextView)

            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTextTap(_:)))
            self.summaryTextView.addGestureRecognizer(tapGesture)
        }

        @objc private func handleTextTap(_ gesture: UITapGestureRecognizer) {
            let location = gesture.location(in: self.summaryTextView)

            guard let textStorage = self.summaryTextView.layoutManager.textStorage else { return }

            let layoutManager = self.summaryTextView.layoutManager
            let textContainer = self.summaryTextView.textContainer

            let characterIndex = layoutManager.characterIndex(
                for: location,
                in: textContainer,
                fractionOfDistanceBetweenInsertionPoints: nil
            )

            guard characterIndex < textStorage.length else { return }

            let attributes = textStorage.attributes(at: characterIndex, effectiveRange: nil)

            if let msgIdNum = attributes[userNavigationKey] as? Int32 {
                if let messageId = self.messageIdMap[msgIdNum] {
                    self.navigateToMessageAction?(messageId)
                }
            } else if let tokenAddress = attributes[tokenNavigationKey] as? String {
                let tokenInfo = self.tokenInfoCache[tokenAddress.lowercased()]

                var effectiveRange = NSRange()
                _ = textStorage.attributes(at: characterIndex, effectiveRange: &effectiveRange)

                let glyphRange = layoutManager.glyphRange(forCharacterRange: effectiveRange, actualCharacterRange: nil)
                var tokenRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

                tokenRect = self.summaryTextView.convert(tokenRect, to: nil)

                self.showTokenDetailAction?(tokenAddress, tokenInfo, tokenRect)
            }
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            for disposable in avatarLoadingDisposables.values {
                disposable.dispose()
            }
            tokenInfoDisposable?.dispose()
            for disposable in tokenLogoDisposables.values {
                disposable.dispose()
            }
        }

        // MARK: - Text Processing

        private func processTokenTags(in text: String) -> (processedText: String, tokens: [(address: String, placeholder: String)]) {
            var result = text
            var tokens: [(address: String, placeholder: String)] = []

            let pattern = "<token>([^<]+)</token>"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
                return (text, [])
            }

            let matches = regex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
            var placeholderIndex = 0
            for match in matches.reversed() {
                guard match.numberOfRanges > 1,
                      let fullRange = Range(match.range, in: result),
                      let addressRange = Range(match.range(at: 1), in: result) else {
                    continue
                }

                var address = String(result[addressRange])

                if isTruncatedAddress(address) {
                    if let fullAddress = recoverFullAddress(from: address) {
                        address = fullAddress
                    } else {
                        continue
                    }
                }

                let placeholder = "{{T\(placeholderIndex)}}"
                placeholderIndex += 1

                result.replaceSubrange(fullRange, with: placeholder)
                tokens.insert((address: address, placeholder: placeholder), at: 0)
            }

            return (result, tokens)
        }

        private func isTruncatedAddress(_ address: String) -> Bool {
            return address.contains("...") || address.contains("*") || address.contains("…")
        }

        private func recoverFullAddress(from truncatedAddress: String) -> String? {
            let cleanAddress = truncatedAddress
                .replacingOccurrences(of: "…", with: "...")

            var prefix = ""
            var suffix = ""

            if let range = cleanAddress.range(of: "...") {
                prefix = String(cleanAddress[..<range.lowerBound])
                suffix = String(cleanAddress[range.upperBound...])
            } else if let range = cleanAddress.range(of: "***") {
                prefix = String(cleanAddress[..<range.lowerBound])
                suffix = String(cleanAddress[range.upperBound...])
            } else if cleanAddress.contains("*") {
                if let firstStar = cleanAddress.firstIndex(of: "*"),
                   let lastStar = cleanAddress.lastIndex(of: "*") {
                    prefix = String(cleanAddress[..<firstStar])
                    suffix = String(cleanAddress[cleanAddress.index(after: lastStar)...])
                }
            }

            guard !prefix.isEmpty && !suffix.isEmpty else {
                return nil
            }

            let searchText = self.originalMessagesText

            if prefix.hasPrefix("0x") {
                let evmPattern = "\\b(\(NSRegularExpression.escapedPattern(for: prefix))[a-fA-F0-9]+\(NSRegularExpression.escapedPattern(for: suffix)))\\b"
                if let regex = try? NSRegularExpression(pattern: evmPattern, options: []),
                   let match = regex.firstMatch(in: searchText, options: [], range: NSRange(searchText.startIndex..., in: searchText)),
                   let range = Range(match.range(at: 1), in: searchText) {
                    let fullAddress = String(searchText[range])
                    if fullAddress.count == 42 {
                        return fullAddress
                    }
                }
            }

            let solanaPattern = "\\b(\(NSRegularExpression.escapedPattern(for: prefix))[1-9A-HJ-NP-Za-km-z]+\(NSRegularExpression.escapedPattern(for: suffix)))\\b"
            if let regex = try? NSRegularExpression(pattern: solanaPattern, options: []),
               let match = regex.firstMatch(in: searchText, options: [], range: NSRange(searchText.startIndex..., in: searchText)),
               let range = Range(match.range(at: 1), in: searchText) {
                let fullAddress = String(searchText[range])
                if fullAddress.count >= 32 && fullAddress.count <= 44 {
                    return fullAddress
                }
            }

            return nil
        }

        private func processUserTags(in text: String) -> (processedText: String, users: [(username: String, messageId: Int32?, placeholder: String)]) {
            var result = text
            var users: [(username: String, messageId: Int32?, placeholder: String)] = []

            let pattern = "<user(?:\\s+m=\"(\\d+)\")?>([^<]+)</user>"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
                return (text, [])
            }

            let matches = regex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))

            var placeholderIndex = 0
            for match in matches.reversed() {
                guard match.numberOfRanges >= 3,
                      let fullRange = Range(match.range, in: result),
                      let usernameRange = Range(match.range(at: 2), in: result) else {
                    continue
                }

                let username = String(result[usernameRange])

                var messageId: Int32? = nil
                if match.range(at: 1).location != NSNotFound,
                   let idRange = Range(match.range(at: 1), in: result) {
                    let idString = String(result[idRange])
                    messageId = Int32(idString)
                }

                let placeholder = "{{U\(placeholderIndex)}}"
                placeholderIndex += 1

                result.replaceSubrange(fullRange, with: placeholder)
                users.insert((username: username, messageId: messageId, placeholder: placeholder), at: 0)
            }

            return (result, users)
        }

        private func preprocessMarkdown(_ text: String) -> String {
            var result = text

            let headerPattern = "^(#{1,6})\\s+(.+?)$"
            if let regex = try? NSRegularExpression(pattern: headerPattern, options: .anchorsMatchLines) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    options: [],
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: "\n**$2**\n"
                )
            }

            let bulletPattern = "^[\\-\\*]\\s+(.+?)$"
            if let regex = try? NSRegularExpression(pattern: bulletPattern, options: .anchorsMatchLines) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    options: [],
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: "• $1"
                )
            }

            let multipleNewlines = "\n{3,}"
            if let regex = try? NSRegularExpression(pattern: multipleNewlines, options: []) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    options: [],
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: "\n\n"
                )
            }

            return result.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // MARK: - Avatar Handling

        private func generatePlaceholderAvatar(for peer: Peer, size: CGFloat) -> UIImage? {
            let avatarSize = CGSize(width: size, height: size)
            let enginePeer = EnginePeer(peer)

            var displayLetters = enginePeer.displayLetters
            if displayLetters.isEmpty {
                let title = peer.debugDisplayTitle
                let components = title.components(separatedBy: " ")
                if components.count >= 2 {
                    displayLetters = [String(components[0].prefix(1)), String(components[1].prefix(1))]
                } else if !title.isEmpty {
                    displayLetters = [String(title.prefix(1))]
                }
            }

            if displayLetters.isEmpty {
                displayLetters = ["?"]
            }

            let image = generateImage(avatarSize, rotatedContext: { contextSize, context in
                context.clear(CGRect(origin: .zero, size: contextSize))
                drawPeerAvatarLetters(
                    context: context,
                    size: contextSize,
                    round: true,
                    font: avatarPlaceholderFont(size: size * 0.4),
                    letters: displayLetters,
                    peerId: enginePeer.id,
                    nameColor: enginePeer.nameColor
                )
            })

            if image == nil {
                let colorIndex = abs(Int(enginePeer.id.id._internalGetInt64Value())) % 7
                let colors: [UIColor] = [
                    UIColor(rgb: 0xfc5c51), UIColor(rgb: 0xfa790f), UIColor(rgb: 0x895dd5),
                    UIColor(rgb: 0x0fb297), UIColor(rgb: 0x00c2ed), UIColor(rgb: 0x3ca5ec),
                    UIColor(rgb: 0x3d72ed)
                ]
                return generateFilledCircleImage(diameter: size, color: colors[colorIndex])
            }

            return image
        }

        private func loadAvatar(for peer: Peer, size: CGFloat, completion: @escaping () -> Void) {
            guard let context = self.context else {
                completion()
                return
            }

            let peerId = peer.id

            if avatarCache[peerId] != nil {
                completion()
                return
            }
            if avatarLoadingDisposables[peerId] != nil {
                completion()
                return
            }

            let avatarSize = CGSize(width: size * 2, height: size * 2)

            let peerSignal = context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
            |> mapToSignal { fullPeer -> Signal<UIImage?, NoError> in
                guard let fullPeer else {
                    return peerAvatarCompleteImage(
                        postbox: context.account.postbox,
                        network: context.account.network,
                        peer: EnginePeer(peer),
                        size: avatarSize,
                        round: true,
                        font: avatarPlaceholderFont(size: size * 0.4),
                        drawLetters: true
                    )
                }
                return peerAvatarCompleteImage(
                    postbox: context.account.postbox,
                    network: context.account.network,
                    peer: fullPeer,
                    size: avatarSize,
                    round: true,
                    font: avatarPlaceholderFont(size: size * 0.4),
                    drawLetters: true
                )
            }

            let disposable = (peerSignal
            |> take(1)
            |> deliverOnMainQueue).start(next: { [weak self] image in
                if let self, let image {
                    self.avatarCache[peerId] = image
                }
                self?.avatarLoadingDisposables.removeValue(forKey: peerId)
                completion()
            }, completed: { [weak self] in
                self?.avatarLoadingDisposables.removeValue(forKey: peerId)
                completion()
            })

            avatarLoadingDisposables[peerId] = disposable
        }

        private func preloadAvatars(for peers: [Peer], size: CGFloat, completion: @escaping () -> Void) {
            guard !peers.isEmpty else {
                completion()
                return
            }

            var pendingCount = peers.count
            let lock = NSLock()

            for peer in peers {
                loadAvatar(for: peer, size: size) {
                    lock.lock()
                    pendingCount -= 1
                    let isDone = pendingCount == 0
                    lock.unlock()

                    if isDone {
                        completion()
                    }
                }
            }
        }

        private func getAvatarImage(for peer: Peer, size: CGFloat) -> UIImage? {
            let enginePeer = EnginePeer(peer)

            if let cached = avatarCache[enginePeer.id] {
                let targetSize = CGSize(width: size, height: size)
                UIGraphicsBeginImageContextWithOptions(targetSize, false, 0)
                cached.draw(in: CGRect(origin: .zero, size: targetSize))
                let resized = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                return resized
            }

            return generatePlaceholderAvatar(for: peer, size: size)
        }

        private func createAvatarAttachment(for peer: Peer, fontSize: CGFloat) -> NSAttributedString {
            let avatarSize: CGFloat = fontSize * 1.3
            guard let avatarImage = getAvatarImage(for: peer, size: avatarSize) else {
                return NSAttributedString(string: "")
            }

            let attachment = NSTextAttachment()
            attachment.image = avatarImage

            let yOffset = (fontSize - avatarSize) / 2.0 - 2.0
            attachment.bounds = CGRect(x: 0, y: yOffset, width: avatarSize, height: avatarSize)

            let avatarString = NSMutableAttributedString(attachment: attachment)
            avatarString.append(NSAttributedString(string: " "))

            return avatarString
        }

        private func createTokenAttachment(for address: String, fontSize: CGFloat, linkColor: UIColor) -> NSAttributedString {
            let result = NSMutableAttributedString()
            let tokenSize: CGFloat = fontSize * 1.2

            let tokenInfo = self.tokenInfoCache[address.lowercased()]

            if let logo = tokenLogoCache[address.lowercased()] {
                let attachment = NSTextAttachment()
                attachment.image = logo

                let yOffset = (fontSize - tokenSize) / 2.0 - 1.5
                attachment.bounds = CGRect(x: 0, y: yOffset, width: tokenSize, height: tokenSize)

                result.append(NSAttributedString(attachment: attachment))
                result.append(NSAttributedString(string: " "))
            } else if tokenInfo?.imageUrl != nil {
                loadTokenLogo(for: address)
            }

            let displayName: String
            if let info = tokenInfo {
                displayName = "$\(info.symbol)"
            } else {
                displayName = FRAddressFormatting.shortenAddress(address)
            }

            let nameString = NSMutableAttributedString(string: displayName, attributes: [
                .font: UIFont.systemFont(ofSize: fontSize, weight: .medium),
                .foregroundColor: linkColor,
                self.tokenNavigationKey: address
            ])

            result.append(nameString)

            return result
        }

        private func loadTokenLogo(for address: String) {
            let normalizedAddress = address.lowercased()

            guard tokenLogoCache[normalizedAddress] == nil,
                  tokenLogoDisposables[normalizedAddress] == nil,
                  let tokenInfo = tokenInfoCache[normalizedAddress],
                  let imageUrl = tokenInfo.imageUrl,
                  let context = self.context else {
                return
            }

            let disposable = (context.engine.resources.httpData(url: imageUrl)
            |> map { data -> UIImage? in
                return UIImage(data: data)
            }
            |> deliverOnMainQueue).start(next: { [weak self] image in
                guard let self = self else { return }
                if let image = image {
                    let size: CGFloat = 32
                    UIGraphicsBeginImageContextWithOptions(CGSize(width: size, height: size), false, 0)
                    let rect = CGRect(origin: .zero, size: CGSize(width: size, height: size))
                    UIBezierPath(ovalIn: rect).addClip()
                    image.draw(in: rect)
                    let circularImage = UIGraphicsGetImageFromCurrentImageContext()
                    UIGraphicsEndImageContext()

                    self.tokenLogoCache[normalizedAddress] = circularImage
                    self.componentState?.updated(transition: .immediate)
                }
                self.tokenLogoDisposables.removeValue(forKey: normalizedAddress)
            })

            tokenLogoDisposables[normalizedAddress] = disposable
        }

        // MARK: - Token Info

        private var lastFetchedText: String = ""

        private func fetchTokenInfoIfNeeded(from text: String) {
            guard text != lastFetchedText else { return }
            lastFetchedText = text

            let addresses = extractTokenAddresses(from: text)
            guard !addresses.isEmpty else { return }

            let newAddresses = addresses.filter { tokenInfoCache[$0.lowercased()] == nil }
            guard !newAddresses.isEmpty else { return }

            tokenInfoDisposable?.dispose()
            tokenInfoDisposable = (DexScreenerService.shared.fetchMultipleTokenInfo(addresses: newAddresses)
            |> deliverOnMainQueue).start(next: { [weak self] tokenInfoDict in
                guard let self = self else { return }
                for (address, info) in tokenInfoDict {
                    self.tokenInfoCache[address.lowercased()] = info
                }
                self.componentState?.updated(transition: .immediate)
            })
        }

        private func extractTokenAddresses(from text: String) -> [String] {
            var addresses: [String] = []

            let tagPattern = "<token>([^<]+)</token>"
            if let regex = try? NSRegularExpression(pattern: tagPattern, options: []) {
                let matches = regex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
                for match in matches {
                    if match.numberOfRanges > 1,
                       let range = Range(match.range(at: 1), in: text) {
                        addresses.append(String(text[range]))
                    }
                }
            }

            let evmPattern = "\\b(0x[a-fA-F0-9]{40})\\b"
            if let regex = try? NSRegularExpression(pattern: evmPattern, options: []) {
                let matches = regex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
                for match in matches {
                    if let range = Range(match.range(at: 1), in: text) {
                        let addr = String(text[range])
                        if !addresses.contains(addr) {
                            addresses.append(addr)
                        }
                    }
                }
            }

            let solanaPattern = "\\b([1-9A-HJ-NP-Za-km-z]{32,44})\\b"
            if let regex = try? NSRegularExpression(pattern: solanaPattern, options: []) {
                let matches = regex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
                for match in matches {
                    if let range = Range(match.range(at: 1), in: text) {
                        let addr = String(text[range])
                        if ChainDetection.detectChainType(address: addr) == "solana" && !addresses.contains(addr) {
                            addresses.append(addr)
                        }
                    }
                }
            }

            return addresses
        }

        // MARK: - Update

        private weak var componentState: EmptyComponentState?

        func update(component: FRSummaryContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            self.dismissAction = component.dismiss
            self.navigateToMessageAction = component.navigateToMessage
            self.openSettingsAction = component.openSettings
            self.showTokenDetailAction = component.showTokenDetail
            self.messageIdMap = component.messageIdMap
            self.messagePeerMap = component.messagePeerMap
            self.context = component.context
            self.originalMessagesText = component.originalMessagesText
            self.componentState = state

            self.fetchTokenInfoIfNeeded(from: component.summaryText)

            let peersToLoad = Array(component.messagePeerMap.values)
            if !peersToLoad.isEmpty {
                let avatarSize: CGFloat = 16.0 * 1.3
                let needsRefresh = peersToLoad.contains { self.avatarCache[EnginePeer($0).id] == nil }
                if needsRefresh {
                    Queue.mainQueue().after(0.1) { [weak self, weak state] in
                        guard let self else { return }
                        self.preloadAvatars(for: peersToLoad, size: avatarSize) { [weak state] in
                            Queue.mainQueue().async {
                                state?.updated(transition: .immediate)
                            }
                        }
                    }
                }
            }

            let theme = component.theme
            let isDark = theme.overallDarkAppearance
            let textColor = theme.list.itemPrimaryTextColor
            let iconColor = theme.chat.inputPanel.panelControlColor

            let sideInset: CGFloat = 16.0
            let topInset: CGFloat = 16.0
            let headerHeight: CGFloat = 56.0
            let buttonSize: CGFloat = 44.0
            let minContentHeight: CGFloat = 300.0

            let closeButtonSize = self.closeButton.update(
                transition: transition,
                component: AnyComponent(GlassBarButtonComponent(
                    size: CGSize(width: buttonSize, height: buttonSize),
                    backgroundColor: nil,
                    isDark: isDark,
                    state: .glass,
                    component: AnyComponentWithIdentity(id: "close", component: AnyComponent(
                        BundleIconComponent(name: "Navigation/Close", tintColor: iconColor)
                    )),
                    action: { [weak self] _ in
                        self?.dismissAction?()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: buttonSize, height: buttonSize)
            )
            if let closeButtonView = self.closeButton.view {
                if closeButtonView.superview == nil {
                    self.addSubview(closeButtonView)
                }
                transition.setFrame(view: closeButtonView, frame: CGRect(x: sideInset, y: topInset, width: closeButtonSize.width, height: closeButtonSize.height))
            }

            let settingsButtonSize = self.settingsButton.update(
                transition: transition,
                component: AnyComponent(GlassBarButtonComponent(
                    size: CGSize(width: buttonSize, height: buttonSize),
                    backgroundColor: nil,
                    isDark: isDark,
                    state: .glass,
                    component: AnyComponentWithIdentity(id: "settings", component: AnyComponent(
                        BundleIconComponent(name: "Chat/Context Menu/Settings", tintColor: iconColor)
                    )),
                    action: { [weak self] _ in
                        self?.openSettingsAction?()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: buttonSize, height: buttonSize)
            )
            if let settingsButtonView = self.settingsButton.view {
                if settingsButtonView.superview == nil {
                    self.addSubview(settingsButtonView)
                }
                transition.setFrame(view: settingsButtonView, frame: CGRect(x: availableSize.width - sideInset - settingsButtonSize.width, y: topInset, width: settingsButtonSize.width, height: settingsButtonSize.height))
            }

            let titleSize = self.titleLabel.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: "AI Summary", attributes: [.font: Font.semibold(17.0), .foregroundColor: textColor])),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 120, height: 34)
            )
            if let titleView = self.titleLabel.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: CGRect(x: (availableSize.width - titleSize.width) / 2, y: topInset + (buttonSize - titleSize.height) / 2, width: titleSize.width, height: titleSize.height))
            }

            var contentY: CGFloat = 8.0

            if !component.summaryTitle.isEmpty && !component.isLoading {
                let summaryTitleSize = self.summaryTitleLabel.update(
                    transition: transition,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: component.summaryTitle, attributes: [.font: Font.bold(18.0), .foregroundColor: textColor])),
                        horizontalAlignment: .natural,
                        maximumNumberOfLines: 2
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2, height: 60)
                )
                if let summaryTitleView = self.summaryTitleLabel.view {
                    if summaryTitleView.superview == nil {
                        self.scrollView.addSubview(summaryTitleView)
                    }
                    summaryTitleView.isHidden = false
                    transition.setFrame(view: summaryTitleView, frame: CGRect(x: sideInset, y: contentY, width: summaryTitleSize.width, height: summaryTitleSize.height))
                }
                contentY += summaryTitleSize.height + 12.0
            } else {
                self.summaryTitleLabel.view?.isHidden = true
            }

            if let notice = component.truncationNotice {
                let warningColor = UIColor.systemOrange
                let truncationSize = self.truncationLabel.update(
                    transition: transition,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: notice, attributes: [.font: Font.regular(13.0), .foregroundColor: warningColor])),
                        horizontalAlignment: .natural,
                        maximumNumberOfLines: 2
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2, height: 40)
                )
                if let truncationView = self.truncationLabel.view {
                    if truncationView.superview == nil {
                        self.scrollView.addSubview(truncationView)
                    }
                    truncationView.isHidden = false
                    transition.setFrame(view: truncationView, frame: CGRect(x: sideInset, y: contentY, width: truncationSize.width, height: truncationSize.height))
                }
                contentY += truncationSize.height + 8.0
            } else {
                self.truncationLabel.view?.isHidden = true
            }

            self.activityIndicator.color = textColor

            if component.isLoading && component.summaryText.isEmpty {
                self.activityIndicator.isHidden = false
                self.activityIndicator.startAnimating()
                self.activityIndicator.frame = CGRect(x: (availableSize.width - 20) / 2, y: contentY + 40, width: 20, height: 20)
                contentY += 100
                self.summaryTextView.isHidden = true
            } else {
                self.activityIndicator.isHidden = true
                self.activityIndicator.stopAnimating()

                let linkColor = theme.list.itemAccentColor
                let markdownAttributes = MarkdownAttributes(
                    body: MarkdownAttributeSet(font: Font.regular(16.0), textColor: textColor),
                    bold: MarkdownAttributeSet(font: Font.semibold(16.0), textColor: textColor),
                    link: MarkdownAttributeSet(font: Font.regular(16.0), textColor: linkColor),
                    linkAttribute: { _ in return nil }
                )

                let (tokenProcessedText, tokenInfos) = self.processTokenTags(in: component.summaryText)
                let (userProcessedText, userInfos) = self.processUserTags(in: tokenProcessedText)
                let processedText = self.preprocessMarkdown(userProcessedText)
                let attributedText = parseMarkdownIntoAttributedString(processedText, attributes: markdownAttributes)

                let mutableAttrText = NSMutableAttributedString(attributedString: attributedText)

                for tokenInfo in tokenInfos.reversed() {
                    let placeholder = tokenInfo.placeholder
                    let address = tokenInfo.address

                    let fullString = mutableAttrText.string
                    if let range = fullString.range(of: placeholder) {
                        let nsRange = NSRange(range, in: fullString)

                        let replacement = self.createTokenAttachment(for: address, fontSize: 16.0, linkColor: linkColor)
                        mutableAttrText.replaceCharacters(in: nsRange, with: replacement)
                    }
                }

                let baseFontSize: CGFloat = 16.0

                for userInfo in userInfos.reversed() {
                    let placeholder = userInfo.placeholder
                    let username = userInfo.username

                    let fullString = mutableAttrText.string
                    if let range = fullString.range(of: placeholder) {
                        let nsRange = NSRange(range, in: fullString)

                        let replacement = NSMutableAttributedString()

                        if let msgIdNum = userInfo.messageId {
                            if let peer = self.messagePeerMap[msgIdNum] {
                                let avatarString = self.createAvatarAttachment(for: peer, fontSize: baseFontSize)
                                replacement.append(avatarString)
                            }
                        }

                        let usernameString = NSMutableAttributedString(string: username)

                        if nsRange.location < mutableAttrText.length {
                            let existingAttrs = mutableAttrText.attributes(at: nsRange.location, effectiveRange: nil)
                            usernameString.addAttributes(existingAttrs, range: NSRange(location: 0, length: username.count))
                        }

                        if let msgIdNum = userInfo.messageId, self.messageIdMap[msgIdNum] != nil {
                            usernameString.addAttributes([
                                .foregroundColor: linkColor,
                                self.userNavigationKey: msgIdNum
                            ], range: NSRange(location: 0, length: username.count))
                        }

                        replacement.append(usernameString)
                        mutableAttrText.replaceCharacters(in: nsRange, with: replacement)
                    }
                }

                let finalAttributedText = mutableAttrText as NSAttributedString
                self.currentText = component.summaryText

                self.summaryTextView.attributedText = finalAttributedText
                self.summaryTextView.isHidden = false

                let textWidth = availableSize.width - sideInset * 2
                let textSize = self.summaryTextView.sizeThatFits(CGSize(width: textWidth, height: CGFloat.greatestFiniteMagnitude))

                self.summaryTextView.frame = CGRect(x: sideInset, y: contentY, width: textWidth, height: textSize.height)
                contentY += textSize.height + 16.0
            }

            let scrollViewTop = headerHeight + 8.0
            let scrollContentHeight = contentY + 20.0
            let bottomPadding: CGFloat = 40.0

            let naturalHeight = scrollViewTop + scrollContentHeight + bottomPadding
            let maxHeight = component.maxHeight
            let totalHeight = min(max(minContentHeight, naturalHeight), maxHeight)
            let scrollViewHeight = totalHeight - scrollViewTop - bottomPadding

            let scrollViewFrame = CGRect(x: 0, y: scrollViewTop, width: availableSize.width, height: max(scrollViewHeight, 100))
            transition.setFrame(view: self.scrollView, frame: scrollViewFrame)
            self.scrollView.contentSize = CGSize(width: availableSize.width, height: scrollContentHeight)

            return CGSize(width: availableSize.width, height: totalHeight)
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
