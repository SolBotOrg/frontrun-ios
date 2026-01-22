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
import AIModule
import SettingsUI
import GlassBarButtonComponent
import BundleIconComponent

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

private final class ChatSummarySheetScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let peerId: PeerId

    init(context: AccountContext, peerId: PeerId) {
        self.context = context
        self.peerId = peerId
    }

    static func ==(lhs: ChatSummarySheetScreenComponent, rhs: ChatSummarySheetScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.peerId != rhs.peerId {
            return false
        }
        return true
    }

    final class View: UIView {
        private let sheetContent = ComponentView<(ViewControllerComponentContainer.Environment, SheetComponentEnvironment)>()
        private let sheetAnimateOut = ActionSlot<Action<Void>>()

        private var component: ChatSummarySheetScreenComponent?
        private weak var state: EmptyComponentState?
        private var environment: ViewControllerComponentContainer.Environment?

        private var summaryText: String = ""
        private var isLoading: Bool = true
        private var disposable: Disposable?

        override init(frame: CGRect) {
            super.init(frame: frame)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            self.disposable?.dispose()
        }

        func update(component: ChatSummarySheetScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state

            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            self.environment = environment

            // Start fetching messages if not already started
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
                    guard let self, let environment = self.environment else {
                        return
                    }
                    if animated {
                        self.sheetAnimateOut.invoke(Action { _ in
                            environment.controller()?.dismiss()
                        })
                    } else {
                        environment.controller()?.dismiss()
                    }
                }
            )

            // Glass background color - adapts to theme
            let isDark = environment.theme.overallDarkAppearance
            let glassBackgroundColor = isDark 
                ? UIColor(white: 0.1, alpha: 0.85) 
                : UIColor(white: 1.0, alpha: 0.85)

            // Calculate max height for content (85% of available height)
            let maxContentHeight = availableSize.height * 0.85

            let sheetSize = self.sheetContent.update(
                transition: transition,
                component: AnyComponent(SheetComponent(
                    content: AnyComponent(ChatSummaryContentComponent(
                        context: component.context,
                        theme: environment.theme,
                        summaryText: self.summaryText,
                        isLoading: self.isLoading,
                        maxHeight: maxContentHeight,
                        dismiss: { [weak self] in
                            guard let self, let environment = self.environment else {
                                return
                            }
                            self.sheetAnimateOut.invoke(Action { _ in
                                environment.controller()?.dismiss()
                            })
                        },
                        openSettings: { [weak self] in
                            #if DEBUG
                            print("[AI Summary] openSettings called")
                            #endif
                            
                            guard let self else {
                                #if DEBUG
                                print("[AI Summary] openSettings: self is nil")
                                #endif
                                return
                            }
                            
                            guard let environment = self.environment else {
                                #if DEBUG
                                print("[AI Summary] openSettings: environment is nil")
                                #endif
                                return
                            }
                            
                            guard let controller = environment.controller() as? ChatSummarySheetScreen else {
                                #if DEBUG
                                print("[AI Summary] openSettings: controller cast failed")
                                #endif
                                return
                            }
                            
                            let context = component.context

                            // Get navigation controller reference before dismiss
                            let navigationController: NavigationController?
                            if let parentController = controller.parentController() {
                                navigationController = parentController.navigationController as? NavigationController
                            } else {
                                navigationController = controller.navigationController as? NavigationController
                            }

                            #if DEBUG
                            print("[AI Summary] openSettings: navigationController = \(String(describing: navigationController))")
                            #endif

                            let settingsController = aiSummarySettingsController(context: context)
                            
                            // Animate out the sheet, then dismiss and push settings
                            // Note: dismiss completion is not called, so we push directly in the action
                            self.sheetAnimateOut.invoke(Action { [weak navigationController] _ in
                                #if DEBUG
                                print("[AI Summary] openSettings: sheetAnimateOut action invoked, pushing settings")
                                #endif
                                controller.dismiss(completion: nil)
                                
                                // Push after a short delay to ensure dismiss animation completes
                                Queue.mainQueue().after(0.3) {
                                    guard let navigationController else {
                                        #if DEBUG
                                        print("[AI Summary] openSettings: navigationController is nil")
                                        #endif
                                        return
                                    }
                                    #if DEBUG
                                    print("[AI Summary] openSettings: pushing settingsController")
                                    #endif
                                    navigationController.pushViewController(settingsController)
                                }
                            })
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
            let messageCount = config.summaryMessageCount.value

            let messagesSignal = context.account.postbox.aroundMessageHistoryViewForLocation(
                .peer(peerId: peerId, threadId: nil),
                anchor: .upperBound,
                ignoreMessagesInTimestampRange: nil,
                ignoreMessageIds: Set(),
                count: messageCount,
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

                let messageTexts = messages.reversed().compactMap { message -> String? in
                    guard let author = message.author else { return nil }
                    let authorName = EnginePeer(author).displayTitle(strings: context.sharedContext.currentPresentationData.with { $0 }.strings, displayOrder: context.sharedContext.currentPresentationData.with { $0 }.nameDisplayOrder)
                    return "\(authorName): \(message.text)"
                }.joined(separator: "\n")

                self.generateAISummary(context: context, messagesText: messageTexts)
            })
        }

        private func generateAISummary(context: AccountContext, messagesText: String) {
            let config = AIConfigurationStorage.shared.getConfiguration()

            #if DEBUG
            print("[AI Summary] Config - enabled: \(config.enabled), isValid: \(config.isValid), provider: \(config.provider), model: \(config.model)")
            print("[AI Summary] Messages text length: \(messagesText.count)")
            #endif

            guard config.isValid && config.enabled else {
                self.summaryText = "AI is not configured or enabled. Please check settings."
                self.isLoading = false
                self.state?.updated(transition: .immediate)
                return
            }

            let service = AIService(configuration: config)
            // Use custom prompt from configuration
            let systemPrompt = config.effectiveSummaryPrompt
            let userPrompt = "Here are the chat messages to summarize:\n\n\(messagesText)"

            let messages = [
                AIMessage(role: "system", content: systemPrompt),
                AIMessage(role: "user", content: userPrompt)
            ]

            #if DEBUG
            print("[AI Summary] Starting AI request...")
            #endif

            self.disposable?.dispose()
            self.disposable = service.sendMessage(messages: messages, stream: true).start(
                next: { [weak self] chunk in
                    guard let self else { return }

                    #if DEBUG
                    print("[AI Summary] Received chunk - content length: \(chunk.content.count), isComplete: \(chunk.isComplete)")
                    #endif

                    Queue.mainQueue().async {
                        if !chunk.content.isEmpty {
                            self.summaryText += chunk.content
                            self.state?.updated(transition: .immediate)
                        }

                        if chunk.isComplete {
                            self.isLoading = false
                            self.state?.updated(transition: .immediate)
                        }
                    }
                },
                error: { [weak self] error in
                    guard let self else { return }

                    #if DEBUG
                    print("[AI Summary] Error: \(error)")
                    #endif

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

                    #if DEBUG
                    print("[AI Summary] Completed - summaryText length: \(self.summaryText.count)")
                    #endif

                    Queue.mainQueue().async {
                        self.isLoading = false
                        // Only show "no summary" if we really got nothing
                        if self.summaryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            self.summaryText = "No summary was generated. Please check your AI configuration in Settings."
                        }
                        self.state?.updated(transition: .immediate)
                    }
                }
            )
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

// Content component with glass buttons
private final class ChatSummaryContentComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let theme: PresentationTheme
    let summaryText: String
    let isLoading: Bool
    let maxHeight: CGFloat
    let dismiss: () -> Void
    let openSettings: () -> Void

    init(context: AccountContext, theme: PresentationTheme, summaryText: String, isLoading: Bool, maxHeight: CGFloat, dismiss: @escaping () -> Void, openSettings: @escaping () -> Void) {
        self.context = context
        self.theme = theme
        self.summaryText = summaryText
        self.isLoading = isLoading
        self.maxHeight = maxHeight
        self.dismiss = dismiss
        self.openSettings = openSettings
    }

    static func ==(lhs: ChatSummaryContentComponent, rhs: ChatSummaryContentComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.summaryText != rhs.summaryText {
            return false
        }
        if lhs.isLoading != rhs.isLoading {
            return false
        }
        if lhs.maxHeight != rhs.maxHeight {
            return false
        }
        return true
    }

    final class View: UIView {
        private let scrollView: UIScrollView
        private let closeButton = ComponentView<Empty>()
        private let settingsButton = ComponentView<Empty>()
        private let titleLabel = ComponentView<Empty>()
        private let textComponent = ComponentView<Empty>()
        private let activityIndicator: UIActivityIndicatorView
        private var currentText: String = ""

        private var dismissAction: (() -> Void)?
        private var openSettingsAction: (() -> Void)?

        override init(frame: CGRect) {
            self.scrollView = UIScrollView()
            self.scrollView.showsVerticalScrollIndicator = true
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.alwaysBounceVertical = true

            if #available(iOS 13.0, *) {
                self.activityIndicator = UIActivityIndicatorView(style: .medium)
                self.activityIndicator.color = .white
            } else {
                self.activityIndicator = UIActivityIndicatorView(style: .white)
            }

            super.init(frame: frame)

            self.addSubview(self.scrollView)
            self.scrollView.addSubview(self.activityIndicator)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(component: ChatSummaryContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            self.dismissAction = component.dismiss
            self.openSettingsAction = component.openSettings

            let theme = component.theme
            let isDark = theme.overallDarkAppearance
            let textColor = theme.list.itemPrimaryTextColor
            let iconColor = theme.chat.inputPanel.panelControlColor

            let sideInset: CGFloat = 16.0
            let topInset: CGFloat = 16.0
            let headerHeight: CGFloat = 56.0
            let buttonSize: CGFloat = 44.0
            let minContentHeight: CGFloat = 300.0

            // Update close button with glass style
            let closeButtonSize = self.closeButton.update(
                transition: transition,
                component: AnyComponent(GlassBarButtonComponent(
                    size: CGSize(width: buttonSize, height: buttonSize),
                    backgroundColor: nil,
                    isDark: isDark,
                    state: .glass,
                    component: AnyComponentWithIdentity(id: "close", component: AnyComponent(
                        BundleIconComponent(
                            name: "Navigation/Close",
                            tintColor: iconColor
                        )
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
                transition.setFrame(view: closeButtonView, frame: CGRect(
                    x: sideInset,
                    y: topInset,
                    width: closeButtonSize.width,
                    height: closeButtonSize.height
                ))
            }

            // Update settings button with glass style
            let settingsButtonSize = self.settingsButton.update(
                transition: transition,
                component: AnyComponent(GlassBarButtonComponent(
                    size: CGSize(width: buttonSize, height: buttonSize),
                    backgroundColor: nil,
                    isDark: isDark,
                    state: .glass,
                    component: AnyComponentWithIdentity(id: "settings", component: AnyComponent(
                        BundleIconComponent(
                            name: "Chat/Context Menu/Settings",
                            tintColor: iconColor
                        )
                    )),
                    action: { [weak self] _ in
                        #if DEBUG
                        print("[AI Summary] Settings button tapped, openSettingsAction: \(String(describing: self?.openSettingsAction))")
                        #endif
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
                transition.setFrame(view: settingsButtonView, frame: CGRect(
                    x: availableSize.width - sideInset - settingsButtonSize.width,
                    y: topInset,
                    width: settingsButtonSize.width,
                    height: settingsButtonSize.height
                ))
            }

            // Title
            let titleSize = self.titleLabel.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: "AI Summary",
                        attributes: [
                            .font: Font.semibold(17.0),
                            .foregroundColor: textColor
                        ]
                    )),
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
                transition.setFrame(view: titleView, frame: CGRect(
                    x: (availableSize.width - titleSize.width) / 2,
                    y: topInset + (buttonSize - titleSize.height) / 2,
                    width: titleSize.width,
                    height: titleSize.height
                ))
            }

            var contentY: CGFloat = 8.0

            // Update activity indicator color based on theme
            self.activityIndicator.color = textColor

            if component.isLoading && component.summaryText.isEmpty {
                self.activityIndicator.isHidden = false
                self.activityIndicator.startAnimating()
                self.activityIndicator.frame = CGRect(
                    x: (availableSize.width - 20) / 2,
                    y: contentY + 40,
                    width: 20,
                    height: 20
                )
                contentY += 100

                self.textComponent.view?.isHidden = true
            } else {
                self.activityIndicator.isHidden = true
                self.activityIndicator.stopAnimating()

                // Parse markdown with theme-aware colors
                let linkColor = theme.list.itemAccentColor
                let markdownAttributes = MarkdownAttributes(
                    body: MarkdownAttributeSet(
                        font: Font.regular(16.0),
                        textColor: textColor
                    ),
                    bold: MarkdownAttributeSet(
                        font: Font.semibold(16.0),
                        textColor: textColor
                    ),
                    link: MarkdownAttributeSet(
                        font: Font.regular(16.0),
                        textColor: linkColor
                    ),
                    linkAttribute: { _ in return nil }
                )

                // Pre-process markdown to convert unsupported formats
                let processedText = self.preprocessMarkdown(component.summaryText)
                let attributedText = parseMarkdownIntoAttributedString(
                    processedText,
                    attributes: markdownAttributes
                )

                let shouldAnimate = component.summaryText != self.currentText && component.isLoading
                self.currentText = component.summaryText

                let textSize = self.textComponent.update(
                    transition: shouldAnimate ? .easeInOut(duration: 0.15) : .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(attributedText),
                        horizontalAlignment: .natural,
                        maximumNumberOfLines: 0
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2, height: 10000)
                )

                if let textView = self.textComponent.view {
                    textView.isHidden = false
                    if textView.superview == nil {
                        self.scrollView.addSubview(textView)
                    }
                    transition.setFrame(view: textView, frame: CGRect(
                        x: sideInset,
                        y: contentY,
                        width: textSize.width,
                        height: textSize.height
                    ))
                }
                contentY += textSize.height + 16.0
            }

            // Calculate heights
            let scrollViewTop = headerHeight + 8.0
            let scrollContentHeight = contentY + 20.0
            let bottomPadding: CGFloat = 40.0
            
            // Total natural height (header + content + padding)
            let naturalHeight = scrollViewTop + scrollContentHeight + bottomPadding
            
            // Limit to max height (85% of screen)
            let maxHeight = component.maxHeight
            let totalHeight = min(max(minContentHeight, naturalHeight), maxHeight)
            
            // Calculate scroll view height based on available space
            let scrollViewHeight = totalHeight - scrollViewTop - bottomPadding
            
            let scrollViewFrame = CGRect(
                x: 0,
                y: scrollViewTop,
                width: availableSize.width,
                height: max(scrollViewHeight, 100)
            )
            transition.setFrame(view: self.scrollView, frame: scrollViewFrame)

            // Update scroll content size
            self.scrollView.contentSize = CGSize(width: availableSize.width, height: scrollContentHeight)

            return CGSize(width: availableSize.width, height: totalHeight)
        }

        // Pre-process markdown to convert unsupported formats to supported ones
        private func preprocessMarkdown(_ text: String) -> String {
            var result = text

            // Convert headers (## Header -> **Header**)
            let headerPattern = "^(#{1,6})\\s+(.+?)$"
            if let regex = try? NSRegularExpression(pattern: headerPattern, options: .anchorsMatchLines) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    options: [],
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: "\n**$2**\n"
                )
            }

            // Convert bullet points (- item or * item -> • item)
            let bulletPattern = "^[\\-\\*]\\s+(.+?)$"
            if let regex = try? NSRegularExpression(pattern: bulletPattern, options: .anchorsMatchLines) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    options: [],
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: "• $1"
                )
            }

            // Convert numbered lists (1. item -> 1. item) - keep as is
            // The numbered lists are already readable

            // Clean up multiple newlines
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
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
