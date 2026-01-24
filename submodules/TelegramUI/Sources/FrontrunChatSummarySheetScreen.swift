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
import SheetComponent
import MultilineTextComponent
import Markdown
import FRServices
import FRModels
import SettingsUI
import GlassBarButtonComponent
import BundleIconComponent
import AvatarNode
import ContextUI
import UndoUI

// MARK: - Helper Functions

private func shortenTokenAddress(_ address: String) -> String {
    guard address.count > 12 else { return address }
    let prefix = address.prefix(6)
    let suffix = address.suffix(4)
    return "\(prefix)...\(suffix)"
}

// MARK: - ChatSummarySheetScreen

final class ChatSummarySheetScreen: ViewControllerComponentContainer {
    private let context: AccountContext
    private let peerId: PeerId

    public var parentController: () -> ViewController? = { return nil }

    init(context: AccountContext, peerId: PeerId) {
        self.context = context
        self.peerId = peerId

        super.init(context: context, component: ChatSummarySheetScreenComponent(
            context: context,
            peerId: peerId
        ), navigationBarAppearance: .none, theme: .default)

        self.statusBar.statusBarStyle = .Ignore
        self.navigationPresentation = .flatModal
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.disablesInteractiveModalDismiss = false
    }
}

// MARK: - ChatSummarySheetScreenComponent

private final class ChatSummarySheetScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let peerId: PeerId

    init(context: AccountContext, peerId: PeerId) {
        self.context = context
        self.peerId = peerId
    }

    static func ==(lhs: ChatSummarySheetScreenComponent, rhs: ChatSummarySheetScreenComponent) -> Bool {
        if lhs.context !== rhs.context { return false }
        if lhs.peerId != rhs.peerId { return false }
        return true
    }

    final class View: UIView {
        private let sheetContent = ComponentView<(ViewControllerComponentContainer.Environment, SheetComponentEnvironment)>()
        private let sheetAnimateOut = ActionSlot<Action<Void>>()

        private var component: ChatSummarySheetScreenComponent?
        private weak var state: EmptyComponentState?
        private var environment: ViewControllerComponentContainer.Environment?

        private var summaryText: String = ""
        private var summaryTitle: String = ""
        private var truncationNotice: String? = nil
        private var isLoading: Bool = true
        private var disposable: Disposable?
        private var messageIdMap: [Int32: MessageId] = [:]
        private var messagePeerMap: [Int32: Peer] = [:]
        private var originalMessagesText: String = ""  // For token address fallback

        override init(frame: CGRect) {
            super.init(frame: frame)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            self.disposable?.dispose()
            self.tokenDetailDisposable?.dispose()
        }

        func update(component: ChatSummarySheetScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state

            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            self.environment = environment

            if self.disposable == nil {
                self.isLoading = true
                self.summaryText = ""
                self.fetchMessagesAndGenerateSummary(context: component.context, peerId: component.peerId)
            }

            let sheetEnvironment = SheetComponentEnvironment(
                isDisplaying: environment.isVisible,
                isCentered: environment.metrics.widthClass == .regular,
                hasInputHeight: !environment.inputHeight.isZero,
                regularMetricsSize: CGSize(width: 430.0, height: min(availableSize.height * 0.85, 600.0)),
                dismiss: { [weak self] animated in
                    guard let self, let environment = self.environment else { return }
                    if animated {
                        self.sheetAnimateOut.invoke(Action { _ in
                            environment.controller()?.dismiss()
                        })
                    } else {
                        environment.controller()?.dismiss()
                    }
                }
            )

            let isDark = environment.theme.overallDarkAppearance
            let glassBackgroundColor = isDark 
                ? UIColor(white: 0.1, alpha: 0.85) 
                : UIColor(white: 1.0, alpha: 0.85)

            let maxContentHeight = availableSize.height * 0.85

            let sheetSize = self.sheetContent.update(
                transition: transition,
                component: AnyComponent(SheetComponent(
                    content: AnyComponent(ChatSummaryContentComponent(
                        context: component.context,
                        peerId: component.peerId,
                        theme: environment.theme,
                        summaryTitle: self.summaryTitle,
                        summaryText: self.summaryText,
                        truncationNotice: self.truncationNotice,
                        messageIdMap: self.messageIdMap,
                        messagePeerMap: self.messagePeerMap,
                        isLoading: self.isLoading,
                        maxHeight: maxContentHeight,
                        originalMessagesText: self.originalMessagesText,
                        dismiss: { [weak self] in
                            guard let self, let environment = self.environment else { return }
                            self.sheetAnimateOut.invoke(Action { _ in
                                environment.controller()?.dismiss()
                            })
                        },
                        navigateToMessage: { [weak self] messageId in
                            guard let self, let environment = self.environment else { return }
                            guard let controller = environment.controller() as? ChatSummarySheetScreen else { return }
                            
                            let context = component.context
                            let peerId = component.peerId
                            let navigationController: NavigationController?
                            if let parentController = controller.parentController() {
                                navigationController = parentController.navigationController as? NavigationController
                            } else {
                                navigationController = controller.navigationController as? NavigationController
                            }
                            
                            self.sheetAnimateOut.invoke(Action { [weak navigationController] _ in
                                controller.dismiss(completion: nil)
                                
                                Queue.mainQueue().after(0.3) {
                                    guard let navigationController else { return }
                                    
                                    let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
                                    |> deliverOnMainQueue).start(next: { peer in
                                        guard let peer else { return }
                                        
                                        context.sharedContext.navigateToChatController(NavigateToChatControllerParams(
                                            navigationController: navigationController,
                                            context: context,
                                            chatLocation: .peer(peer),
                                            subject: .message(id: .id(messageId), highlight: ChatControllerSubject.MessageHighlight(quote: nil), timecode: nil, setupReply: false),
                                            keepStack: .always
                                        ))
                                    })
                                }
                            })
                        },
                        openSettings: { [weak self] in
                            guard let self, let environment = self.environment else { return }
                            guard let controller = environment.controller() as? ChatSummarySheetScreen else { return }
                            
                            let context = component.context
                            let navigationController: NavigationController?
                            if let parentController = controller.parentController() {
                                navigationController = parentController.navigationController as? NavigationController
                            } else {
                                navigationController = controller.navigationController as? NavigationController
                            }

                            let settingsController = aiSummarySettingsController(context: context)
                            
                            self.sheetAnimateOut.invoke(Action { [weak navigationController] _ in
                                controller.dismiss(completion: nil)
                                
                                Queue.mainQueue().after(0.3) {
                                    guard let navigationController else { return }
                                    navigationController.pushViewController(settingsController)
                                }
                            })
                        },
                        showTokenDetail: { [weak self] address, tokenInfo, sourceRect in
                            guard let self, let environment = self.environment else { return }
                            guard let controller = environment.controller() else { return }
                            
                            self.showTokenDetailContextMenu(
                                controller: controller,
                                context: component.context,
                                address: address,
                                tokenInfo: tokenInfo,
                                sourceRect: sourceRect,
                                theme: environment.theme
                            )
                        }
                    )),
                    style: .glass,
                    backgroundColor: .color(glassBackgroundColor),
                    followContentSizeChanges: true,
                    animateOut: self.sheetAnimateOut
                )),
                environment: {
                    environment
                    sheetEnvironment
                },
                containerSize: availableSize
            )

            if let sheetView = self.sheetContent.view {
                if sheetView.superview == nil {
                    self.addSubview(sheetView)
                }
                transition.setFrame(view: sheetView, frame: CGRect(origin: CGPoint(), size: sheetSize))
            }

            return availableSize
        }

        private func fetchMessagesAndGenerateSummary(context: AccountContext, peerId: PeerId) {
            let config = AIConfigurationStorage.shared.getConfiguration()
            let requestedMessageCount = config.summaryMessageCount.value

            let messagesSignal = context.account.postbox.aroundMessageHistoryViewForLocation(
                .peer(peerId: peerId, threadId: nil),
                anchor: .upperBound,
                ignoreMessagesInTimestampRange: nil,
                ignoreMessageIds: Set(),
                count: requestedMessageCount,
                trackHoles: false,
                fixedCombinedReadStates: nil,
                topTaggedMessageIdNamespaces: Set(),
                tag: nil,
                appendMessagesFromTheSameGroup: false,
                namespaces: .not(Namespaces.Message.allNonRegular),
                orderStatistics: []
            )
            |> take(1)
            |> map { view, _, _ -> [Message] in
                return view.entries.map { $0.message }
            }

            self.disposable = (messagesSignal
            |> deliverOnMainQueue).start(next: { [weak self] messages in
                guard let self else { return }

                if messages.isEmpty {
                    self.summaryText = "No messages to summarize."
                    self.isLoading = false
                    self.state?.updated(transition: .immediate)
                    return
                }

                var messageIdMap: [Int32: MessageId] = [:]
                var messagePeerMap: [Int32: Peer] = [:]
                for message in messages {
                    messageIdMap[message.id.id] = message.id
                    if let author = message.author {
                        messagePeerMap[message.id.id] = author
                    }
                }
                self.messageIdMap = messageIdMap
                self.messagePeerMap = messagePeerMap

                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"

                var formattedMessages = messages.reversed().compactMap { message -> String? in
                    guard let author = message.author else { return nil }
                    let authorName = EnginePeer(author).displayTitle(strings: context.sharedContext.currentPresentationData.with { $0 }.strings, displayOrder: context.sharedContext.currentPresentationData.with { $0 }.nameDisplayOrder)
                    let timestamp = dateFormatter.string(from: Date(timeIntervalSince1970: Double(message.timestamp)))
                    return "[id:\(message.id.id)][\(timestamp)] \(authorName): \(message.text)"
                }

                var messageTexts = formattedMessages.joined(separator: "\n")
                let (actualCount, truncated, reason) = config.calculateMaxMessages(messagesText: messageTexts, requestedCount: formattedMessages.count)

                if truncated {
                    formattedMessages = Array(formattedMessages.suffix(actualCount))
                    messageTexts = formattedMessages.joined(separator: "\n")
                    self.truncationNotice = reason
                } else {
                    self.truncationNotice = nil
                }

                self.generateAISummary(context: context, messagesText: messageTexts, messageCount: formattedMessages.count, totalMessages: messages.count)
            })
        }

        private func generateAISummary(context: AccountContext, messagesText: String, messageCount: Int, totalMessages: Int) {
            // Save original messages for token address fallback
            self.originalMessagesText = messagesText
            
            let config = AIConfigurationStorage.shared.getConfiguration()

            guard config.isValid && config.enabled else {
                self.summaryText = "AI is not configured or enabled. Please check settings."
                self.isLoading = false
                self.state?.updated(transition: .immediate)
                return
            }

            let service = AIService(configuration: config)
            let systemPrompt = config.effectiveSummarySystemPrompt

            var userPromptContent = ""
            if !config.summaryUserPrompt.isEmpty {
                userPromptContent = config.summaryUserPrompt + "\n\n"
            }

            if messageCount < totalMessages {
                userPromptContent += "Note: Due to context size limit, only the latest \(messageCount) messages are included (total: \(totalMessages)).\n\n"
            }

            userPromptContent += "Here are the chat messages to summarize (\(messageCount) messages):\n\n\(messagesText)"

            let messages = [
                AIMessage(role: "system", content: systemPrompt),
                AIMessage(role: "user", content: userPromptContent)
            ]

            self.disposable?.dispose()
            self.disposable = service.sendMessage(messages: messages, stream: true).start(
                next: { [weak self] chunk in
                    guard let self else { return }

                    Queue.mainQueue().async {
                        if !chunk.content.isEmpty {
                            self.summaryText += chunk.content
                            if self.summaryTitle.isEmpty {
                                self.extractTitle()
                            }
                            self.state?.updated(transition: .immediate)
                        }

                        if chunk.isComplete {
                            self.isLoading = false
                            self.extractTitle()
                            self.state?.updated(transition: .immediate)
                        }
                    }
                },
                error: { [weak self] error in
                    guard let self else { return }

                    Queue.mainQueue().async {
                        self.isLoading = false
                        switch error {
                        case .invalidConfiguration:
                            self.summaryText = "**Error:** AI is not configured. Please go to Settings to configure your API key."
                        case .networkError(let err):
                            self.summaryText = "**Network error:** \(err.localizedDescription)"
                        case .invalidResponse:
                            self.summaryText = "**Error:** Invalid response from AI service"
                        case .apiError(let message):
                            self.summaryText = "**API error:** \(message)"
                        case .decodingError:
                            self.summaryText = "**Error:** Failed to decode response"
                        }
                        self.state?.updated(transition: .immediate)
                    }
                },
                completed: { [weak self] in
                    guard let self else { return }

                    Queue.mainQueue().async {
                        self.isLoading = false
                        if self.summaryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            self.summaryText = "No summary was generated. Please check your AI configuration in Settings."
                        }
                        self.extractTitle()
                        self.state?.updated(transition: .immediate)
                    }
                }
            )
        }

        private func extractTitle() {
            let text = self.summaryText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }

            let lines = text.components(separatedBy: .newlines)
            if let firstLine = lines.first {
                var title = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
                while title.hasPrefix("#") {
                    title = String(title.dropFirst()).trimmingCharacters(in: .whitespaces)
                }
                title = title.replacingOccurrences(of: "**", with: "")
                if title.count > 50 {
                    title = String(title.prefix(47)) + "..."
                }
                if !title.isEmpty && title.count > 2 {
                    self.summaryTitle = title
                }
            }
        }
        
        // MARK: - Token Detail Action Sheet
        
        private var tokenDetailDisposable: Disposable?
        
        private func showTokenDetailContextMenu(controller: ViewController, context: AccountContext, address: String, tokenInfo: DexTokenInfo?, sourceRect: CGRect, theme: PresentationTheme) {
            // If we have tokenInfo, show immediately
            if let info = tokenInfo {
                self.presentTokenActionSheet(controller: controller, context: context, address: address, tokenInfo: info, theme: theme)
            } else {
                // Fetch token info and then show
                tokenDetailDisposable?.dispose()
                tokenDetailDisposable = (DexScreenerService.shared.fetchTokenInfo(address: address)
                |> deliverOnMainQueue).start(next: { [weak self, weak controller] fetchedInfo in
                    guard let self = self, let controller = controller else { return }
                    self.presentTokenActionSheet(controller: controller, context: context, address: address, tokenInfo: fetchedInfo, theme: theme)
                })
            }
        }
        
        private func presentTokenActionSheet(controller: ViewController, context: AccountContext, address: String, tokenInfo: DexTokenInfo?, theme: PresentationTheme) {
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            
            var items: [ActionSheetItem] = []
            
            // Token info header
            if let info = tokenInfo {
                items.append(TokenInfoActionSheetItem(
                    name: info.name,
                    symbol: info.symbol,
                    price: info.formattedPrice,
                    change: info.formattedPriceChange,
                    isUp: info.isPriceUp,
                    marketCap: info.marketCap != nil ? info.formattedMarketCap : nil,
                    volume: info.volume24h != nil ? info.formattedVolume : nil,
                    imageUrl: info.imageUrl,
                    context: context,
                    theme: theme
                ))
            } else {
                let shortAddr = shortenTokenAddress(address)
                items.append(ActionSheetTextItem(title: "Token: \(shortAddr)\n(No data available)"))
            }
            
            // Prepare URLs
            let dexScreenerUrl: String
            if let info = tokenInfo, let url = info.getDexScreenerUrl() {
                dexScreenerUrl = url
            } else {
                let chain = address.hasPrefix("0x") ? "ethereum" : "solana"
                dexScreenerUrl = "https://dexscreener.com/\(chain)/\(address)"
            }
            
            let explorerName = self.getExplorerName(chainId: tokenInfo?.chainId ?? (address.hasPrefix("0x") ? "ethereum" : "solana"))
            var explorerUrl: String
            if let info = tokenInfo, let url = info.getExplorerUrl() {
                explorerUrl = url
            } else if address.hasPrefix("0x") {
                explorerUrl = "https://etherscan.io/token/\(address)"
            } else {
                explorerUrl = "https://solscan.io/token/\(address)"
            }
            
            let actionSheet = ActionSheetController(presentationData: presentationData)
            
            // Copy address
            items.append(ActionSheetButtonItem(title: "Copy Address", color: .accent, action: { [weak actionSheet, weak controller] in
                actionSheet?.dismissAnimated()
                UIPasteboard.general.string = address
                
                if let controller = controller {
                    let undoController = UndoOverlayController(
                        presentationData: presentationData,
                        content: .copy(text: "Address copied"),
                        elevatedLayout: false,
                        action: { _ in return false }
                    )
                    controller.present(undoController, in: .current)
                }
            }))
            
            // Open in DexScreener
            items.append(ActionSheetButtonItem(title: "Open DexScreener", color: .accent, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                if let url = URL(string: dexScreenerUrl) {
                    context.sharedContext.applicationBindings.openUrl(url.absoluteString)
                }
            }))
            
            // Open in Explorer
            items.append(ActionSheetButtonItem(title: "Open \(explorerName)", color: .accent, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                if let url = URL(string: explorerUrl) {
                    context.sharedContext.applicationBindings.openUrl(url.absoluteString)
                }
            }))
            
            actionSheet.setItemGroups([
                ActionSheetItemGroup(items: items),
                ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                    })
                ])
            ])
            
            controller.present(actionSheet, in: .window(.root))
        }
        
        private func getExplorerName(chainId: String) -> String {
            switch chainId.lowercased() {
            case "ethereum", "eth": return "Etherscan"
            case "bsc", "binance": return "BscScan"
            case "solana": return "Solscan"
            case "arbitrum": return "Arbiscan"
            case "base": return "BaseScan"
            case "polygon": return "PolygonScan"
            case "avalanche", "avax": return "Snowtrace"
            case "optimism": return "Optimistic Etherscan"
            case "fantom", "ftm": return "FTMScan"
            default: return "Explorer"
            }
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

// MARK: - ChatSummaryContentComponent

private final class ChatSummaryContentComponent: Component {
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
    let originalMessagesText: String  // For token address fallback
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

    static func ==(lhs: ChatSummaryContentComponent, rhs: ChatSummaryContentComponent) -> Bool {
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
                
                // Get the bounding rect for the tapped text
                var effectiveRange = NSRange()
                _ = textStorage.attributes(at: characterIndex, effectiveRange: &effectiveRange)
                
                let glyphRange = layoutManager.glyphRange(forCharacterRange: effectiveRange, actualCharacterRange: nil)
                var tokenRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
                
                // Convert to window coordinates
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
                
                // Check if address is truncated and try to recover full address
                if isTruncatedAddress(address) {
                    if let fullAddress = recoverFullAddress(from: address) {
                        address = fullAddress
                    } else {
                        // Skip this token if we can't recover the full address
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
        
        /// Check if address appears to be truncated (contains ... or *)
        private func isTruncatedAddress(_ address: String) -> Bool {
            return address.contains("...") || address.contains("*") || address.contains("…")
        }
        
        /// Try to recover the full address from original messages using partial match
        private func recoverFullAddress(from truncatedAddress: String) -> String? {
            // Extract prefix and suffix from truncated address
            // e.g. "0x1234...5678" -> prefix="0x1234", suffix="5678"
            // e.g. "0x1234***5678" -> prefix="0x1234", suffix="5678"
            
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
                // Find first and last asterisk
                if let firstStar = cleanAddress.firstIndex(of: "*"),
                   let lastStar = cleanAddress.lastIndex(of: "*") {
                    prefix = String(cleanAddress[..<firstStar])
                    suffix = String(cleanAddress[cleanAddress.index(after: lastStar)...])
                }
            }
            
            guard !prefix.isEmpty && !suffix.isEmpty else {
                return nil
            }
            
            // Search in original messages for matching full address
            let searchText = self.originalMessagesText
            
            // Pattern to find full EVM addresses
            if prefix.hasPrefix("0x") {
                let evmPattern = "\\b(\(NSRegularExpression.escapedPattern(for: prefix))[a-fA-F0-9]+\(NSRegularExpression.escapedPattern(for: suffix)))\\b"
                if let regex = try? NSRegularExpression(pattern: evmPattern, options: []),
                   let match = regex.firstMatch(in: searchText, options: [], range: NSRange(searchText.startIndex..., in: searchText)),
                   let range = Range(match.range(at: 1), in: searchText) {
                    let fullAddress = String(searchText[range])
                    // Validate length for EVM
                    if fullAddress.count == 42 {
                        return fullAddress
                    }
                }
            }
            
            // Pattern for Solana addresses (base58)
            let solanaPattern = "\\b(\(NSRegularExpression.escapedPattern(for: prefix))[1-9A-HJ-NP-Za-km-z]+\(NSRegularExpression.escapedPattern(for: suffix)))\\b"
            if let regex = try? NSRegularExpression(pattern: solanaPattern, options: []),
               let match = regex.firstMatch(in: searchText, options: [], range: NSRange(searchText.startIndex..., in: searchText)),
               let range = Range(match.range(at: 1), in: searchText) {
                let fullAddress = String(searchText[range])
                // Validate length for Solana (32-44 chars)
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
            
            // Get token info and logo
            let tokenInfo = self.tokenInfoCache[address.lowercased()]
            
            // Try to add logo if available
            if let logo = tokenLogoCache[address.lowercased()] {
                let attachment = NSTextAttachment()
                attachment.image = logo
                
                let yOffset = (fontSize - tokenSize) / 2.0 - 1.5
                attachment.bounds = CGRect(x: 0, y: yOffset, width: tokenSize, height: tokenSize)
                
                result.append(NSAttributedString(attachment: attachment))
                result.append(NSAttributedString(string: " "))
            } else if tokenInfo?.imageUrl != nil {
                // Load logo asynchronously
                loadTokenLogo(for: address)
            }
            
            // Add token name or short address
            let displayName: String
            if let info = tokenInfo {
                displayName = "$\(info.symbol)"
            } else {
                displayName = shortenTokenAddress(address)
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
            
            // Skip if already loading or loaded
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
                    // Resize and make circular
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
            
            // Extract token addresses from the text
            let addresses = extractTokenAddresses(from: text)
            guard !addresses.isEmpty else { return }
            
            // Filter out addresses we already have
            let newAddresses = addresses.filter { tokenInfoCache[$0.lowercased()] == nil }
            guard !newAddresses.isEmpty else { return }
            
            // Fetch token info for new addresses
            tokenInfoDisposable?.dispose()
            tokenInfoDisposable = (DexScreenerService.shared.fetchMultipleTokenInfo(addresses: newAddresses)
            |> deliverOnMainQueue).start(next: { [weak self] tokenInfoDict in
                guard let self = self else { return }
                for (address, info) in tokenInfoDict {
                    // Store with lowercased key for consistent lookup
                    self.tokenInfoCache[address.lowercased()] = info
                }
                self.componentState?.updated(transition: .immediate)
            })
        }
        
        private func extractTokenAddresses(from text: String) -> [String] {
            var addresses: [String] = []
            
            // Match <token>...</token> tags
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
            
            // Also match raw 0x addresses (42 chars)
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
            
            // Match Solana addresses (base58, 32-44 chars)
            let solanaPattern = "\\b([1-9A-HJ-NP-Za-km-z]{32,44})\\b"
            if let regex = try? NSRegularExpression(pattern: solanaPattern, options: []) {
                let matches = regex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
                for match in matches {
                    if let range = Range(match.range(at: 1), in: text) {
                        let addr = String(text[range])
                        // Validate it looks like a Solana address
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
        
        func update(component: ChatSummaryContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            self.dismissAction = component.dismiss
            self.navigateToMessageAction = component.navigateToMessage
            self.openSettingsAction = component.openSettings
            self.showTokenDetailAction = component.showTokenDetail
            self.messageIdMap = component.messageIdMap
            self.messagePeerMap = component.messagePeerMap
            self.context = component.context
            self.originalMessagesText = component.originalMessagesText
            self.componentState = state
            
            // Fetch token info for addresses in the summary
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

            // Close button
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

            // Settings button
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

            // Header title
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

            // Summary title
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

            // Truncation notice
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

                // Replace token placeholders with logo + name
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

                // Replace user placeholders with avatar + username
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

// MARK: - Token Info ActionSheet Item

private final class TokenInfoActionSheetItem: ActionSheetItem {
    let name: String
    let symbol: String
    let price: String
    let change: String
    let isUp: Bool
    let marketCap: String?
    let volume: String?
    let imageUrl: String?
    let context: AccountContext
    let theme: PresentationTheme
    
    init(name: String, symbol: String, price: String, change: String, isUp: Bool, marketCap: String?, volume: String?, imageUrl: String?, context: AccountContext, theme: PresentationTheme) {
        self.name = name
        self.symbol = symbol
        self.price = price
        self.change = change
        self.isUp = isUp
        self.marketCap = marketCap
        self.volume = volume
        self.imageUrl = imageUrl
        self.context = context
        self.theme = theme
    }
    
    func node(theme: ActionSheetControllerTheme) -> ActionSheetItemNode {
        return TokenInfoActionSheetItemNode(item: self, theme: theme)
    }
    
    func updateNode(_ node: ActionSheetItemNode) {
    }
}

private final class TokenInfoActionSheetItemNode: ActionSheetItemNode {
    private let item: TokenInfoActionSheetItem
    
    private let imageNode: ASImageNode
    private let nameLabel: ImmediateTextNode
    private let priceLabel: ImmediateTextNode
    private let changeLabel: ImmediateTextNode
    private let statsLabel: ImmediateTextNode
    
    private var imageDisposable: Disposable?
    
    init(item: TokenInfoActionSheetItem, theme: ActionSheetControllerTheme) {
        self.item = item
        
        self.imageNode = ASImageNode()
        self.imageNode.contentMode = .scaleAspectFill
        self.imageNode.cornerRadius = 20
        self.imageNode.clipsToBounds = true
        self.imageNode.backgroundColor = theme.secondaryTextColor.withAlphaComponent(0.1)
        
        // Generate placeholder with first letter of symbol
        let placeholderImage = Self.generatePlaceholder(symbol: item.symbol, size: CGSize(width: 40, height: 40), theme: theme)
        self.imageNode.image = placeholderImage
        
        self.nameLabel = ImmediateTextNode()
        self.nameLabel.displaysAsynchronously = false
        self.nameLabel.maximumNumberOfLines = 1
        
        self.priceLabel = ImmediateTextNode()
        self.priceLabel.displaysAsynchronously = false
        self.priceLabel.maximumNumberOfLines = 1
        
        self.changeLabel = ImmediateTextNode()
        self.changeLabel.displaysAsynchronously = false
        self.changeLabel.maximumNumberOfLines = 1
        
        self.statsLabel = ImmediateTextNode()
        self.statsLabel.displaysAsynchronously = false
        self.statsLabel.maximumNumberOfLines = 1
        
        super.init(theme: theme)
        
        self.addSubnode(self.imageNode)
        self.addSubnode(self.nameLabel)
        self.addSubnode(self.priceLabel)
        self.addSubnode(self.changeLabel)
        self.addSubnode(self.statsLabel)
        
        self.nameLabel.attributedText = NSAttributedString(
            string: "\(item.name) ($\(item.symbol))",
            font: Font.semibold(16.0),
            textColor: theme.primaryTextColor
        )
        
        self.priceLabel.attributedText = NSAttributedString(
            string: item.price,
            font: Font.regular(15.0),
            textColor: theme.primaryTextColor
        )
        
        self.changeLabel.attributedText = NSAttributedString(
            string: "24h: \(item.change)",
            font: Font.medium(14.0),
            textColor: item.isUp ? UIColor.systemGreen : UIColor.systemRed
        )
        
        var statsText = ""
        if let mc = item.marketCap {
            statsText += "MCap: \(mc)"
        }
        if let vol = item.volume {
            if !statsText.isEmpty { statsText += " • " }
            statsText += "Vol: \(vol)"
        }
        
        if !statsText.isEmpty {
            self.statsLabel.attributedText = NSAttributedString(
                string: statsText,
                font: Font.regular(13.0),
                textColor: theme.secondaryTextColor
            )
        }
        
        // Load token image from URL
        if let imageUrl = item.imageUrl, URL(string: imageUrl) != nil {
            self.imageDisposable = (item.context.engine.resources.httpData(url: imageUrl)
            |> deliverOnMainQueue).startStrict(next: { [weak self] data in
                if let image = UIImage(data: data) {
                    self?.imageNode.image = image
                }
            })
        }
    }
    
    private static func generatePlaceholder(symbol: String, size: CGSize, theme: ActionSheetControllerTheme) -> UIImage {
        let firstChar = symbol.prefix(1).uppercased()
        
        // Generate color based on symbol hash
        let hash = abs(symbol.hashValue)
        let colors: [UIColor] = [
            UIColor(rgb: 0x5E97F6), // Blue
            UIColor(rgb: 0x9C27B0), // Purple
            UIColor(rgb: 0x00BCD4), // Cyan
            UIColor(rgb: 0x4CAF50), // Green
            UIColor(rgb: 0xFF9800), // Orange
            UIColor(rgb: 0xE91E63), // Pink
            UIColor(rgb: 0x009688), // Teal
            UIColor(rgb: 0x673AB7), // Deep Purple
        ]
        let color = colors[hash % colors.count]
        
        return UIGraphicsImageRenderer(size: size).image { context in
            // Draw circle background
            color.setFill()
            context.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
            
            // Draw letter
            let font = UIFont.systemFont(ofSize: size.width * 0.45, weight: .semibold)
            let textAttributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.white
            ]
            
            let textSize = (firstChar as NSString).size(withAttributes: textAttributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            (firstChar as NSString).draw(in: textRect, withAttributes: textAttributes)
        }
    }
    
    deinit {
        self.imageDisposable?.dispose()
    }
    
    public override func updateLayout(constrainedSize: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        let padding: CGFloat = 16.0
        let imageSize: CGFloat = 40.0
        let spacing: CGFloat = 4.0
        let textLeftOffset = padding + imageSize + 12.0
        let maxTextWidth = constrainedSize.width - textLeftOffset - padding
        
        let nameSize = self.nameLabel.updateLayout(CGSize(width: maxTextWidth, height: .greatestFiniteMagnitude))
        let priceSize = self.priceLabel.updateLayout(CGSize(width: maxTextWidth, height: .greatestFiniteMagnitude))
        let changeSize = self.changeLabel.updateLayout(CGSize(width: maxTextWidth, height: .greatestFiniteMagnitude))
        let statsSize = self.statsLabel.updateLayout(CGSize(width: maxTextWidth, height: .greatestFiniteMagnitude))
        
        var textHeight = nameSize.height + spacing + priceSize.height + spacing + changeSize.height
        if statsSize.width > 0 {
            textHeight += spacing + statsSize.height
        }
        
        let contentHeight = max(imageSize, textHeight)
        let size = CGSize(width: constrainedSize.width, height: padding + contentHeight + padding)
        
        // Layout image on left
        let imageY = (size.height - imageSize) / 2.0
        transition.updateFrame(node: self.imageNode, frame: CGRect(x: padding, y: imageY, width: imageSize, height: imageSize))
        
        // Layout text on right
        var yOffset = padding
        
        transition.updateFrame(node: self.nameLabel, frame: CGRect(origin: CGPoint(x: textLeftOffset, y: yOffset), size: nameSize))
        yOffset += nameSize.height + spacing
        
        transition.updateFrame(node: self.priceLabel, frame: CGRect(origin: CGPoint(x: textLeftOffset, y: yOffset), size: priceSize))
        yOffset += priceSize.height + spacing
        
        transition.updateFrame(node: self.changeLabel, frame: CGRect(origin: CGPoint(x: textLeftOffset, y: yOffset), size: changeSize))
        yOffset += changeSize.height + spacing
        
        if statsSize.width > 0 {
            transition.updateFrame(node: self.statsLabel, frame: CGRect(origin: CGPoint(x: textLeftOffset, y: yOffset), size: statsSize))
        }
        
        self.updateInternalLayout(size, constrainedSize: constrainedSize)
        return size
    }
}
