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
import SettingsUI
import ContextUI
import UndoUI
import FRServices
import FRModels

// MARK: - FRSummarySheetScreenComponent

final class FRSummarySheetScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let peerId: PeerId

    init(context: AccountContext, peerId: PeerId) {
        self.context = context
        self.peerId = peerId
    }

    static func ==(lhs: FRSummarySheetScreenComponent, rhs: FRSummarySheetScreenComponent) -> Bool {
        if lhs.context !== rhs.context { return false }
        if lhs.peerId != rhs.peerId { return false }
        return true
    }

    final class View: UIView {
        private let sheetContent = ComponentView<(ViewControllerComponentContainer.Environment, SheetComponentEnvironment)>()
        private let sheetAnimateOut = ActionSlot<Action<Void>>()

        private var component: FRSummarySheetScreenComponent?
        private weak var state: EmptyComponentState?
        private var environment: ViewControllerComponentContainer.Environment?

        private var summaryText: String = ""
        private var summaryTitle: String = ""
        private var truncationNotice: String? = nil
        private var isLoading: Bool = true
        private var disposable: Disposable?
        private var messageIdMap: [Int32: MessageId] = [:]
        private var messagePeerMap: [Int32: Peer] = [:]
        private var originalMessagesText: String = ""

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

        func update(component: FRSummarySheetScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
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
                    content: AnyComponent(FRSummaryContentComponent(
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
                            guard let controller = environment.controller() as? FRSummarySheetScreen else { return }

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
                            guard let controller = environment.controller() as? FRSummarySheetScreen else { return }

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
            if let info = tokenInfo {
                self.presentTokenActionSheet(controller: controller, context: context, address: address, tokenInfo: info, theme: theme)
            } else {
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

            if let info = tokenInfo {
                items.append(FRTokenInfoActionSheetItem(
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
                let shortAddr = FRAddressFormatting.shortenAddress(address)
                items.append(ActionSheetTextItem(title: "Token: \(shortAddr)\n(No data available)"))
            }

            let dexScreenerUrl: String
            if let info = tokenInfo, let url = info.getDexScreenerUrl() {
                dexScreenerUrl = url
            } else {
                let chain = address.hasPrefix("0x") ? "ethereum" : "solana"
                // URL-encode address for safe interpolation
                let encodedAddress = address.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? address
                dexScreenerUrl = "https://dexscreener.com/\(chain)/\(encodedAddress)"
            }

            let explorerName = FRChainInfo.getExplorerName(for: tokenInfo?.chainId ?? (address.hasPrefix("0x") ? "ethereum" : "solana"))
            var explorerUrl: String
            if let info = tokenInfo, let url = info.getExplorerUrl() {
                explorerUrl = url
            } else {
                // URL-encode address for safe interpolation
                let encodedAddress = address.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? address
                if address.hasPrefix("0x") {
                    explorerUrl = "https://etherscan.io/token/\(encodedAddress)"
                } else {
                    explorerUrl = "https://solscan.io/token/\(encodedAddress)"
                }
            }

            let actionSheet = ActionSheetController(presentationData: presentationData)

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

            items.append(ActionSheetButtonItem(title: "Open DexScreener", color: .accent, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                if let url = URL(string: dexScreenerUrl) {
                    context.sharedContext.applicationBindings.openUrl(url.absoluteString)
                }
            }))

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

    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
