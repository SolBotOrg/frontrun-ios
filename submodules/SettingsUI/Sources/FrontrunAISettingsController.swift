import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import PromptUI
import FrontrunAIModule
import SearchableSelectionScreen

private final class AISettingsControllerArguments {
    let context: AccountContext
    let updateEnabled: (Bool) -> Void
    let updateProvider: (AIProvider) -> Void
    let updateAPIKey: (String) -> Void
    let updateBaseURL: (String) -> Void
    let updateModel: (String) -> Void
    let selectProvider: () -> Void
    let selectModel: () -> Void
    let fetchModels: () -> Void

    init(
        context: AccountContext,
        updateEnabled: @escaping (Bool) -> Void,
        updateProvider: @escaping (AIProvider) -> Void,
        updateAPIKey: @escaping (String) -> Void,
        updateBaseURL: @escaping (String) -> Void,
        updateModel: @escaping (String) -> Void,
        selectProvider: @escaping () -> Void,
        selectModel: @escaping () -> Void,
        fetchModels: @escaping () -> Void
    ) {
        self.context = context
        self.updateEnabled = updateEnabled
        self.updateProvider = updateProvider
        self.updateAPIKey = updateAPIKey
        self.updateBaseURL = updateBaseURL
        self.updateModel = updateModel
        self.selectProvider = selectProvider
        self.selectModel = selectModel
        self.fetchModels = fetchModels
    }
}

private enum AISettingsSection: Int32 {
    case enabled
    case provider
    case apiKey
    case endpoint
}

private enum AISettingsEntry: ItemListNodeEntry {
    case enabled(PresentationTheme, String, Bool)
    case enabledInfo(PresentationTheme, String)

    case providerHeader(PresentationTheme, String)
    case provider(PresentationTheme, String, AIProvider)

    case apiKeyHeader(PresentationTheme, String)
    case apiKey(PresentationTheme, String, String)
    case apiKeyInfo(PresentationTheme, String)

    case endpointHeader(PresentationTheme, String)
    case baseURL(PresentationTheme, String, String)
    case model(PresentationTheme, String, AIProvider)
    case fetchModels(PresentationTheme, Bool)
    case endpointInfo(PresentationTheme, String)

    var section: ItemListSectionId {
        switch self {
        case .enabled, .enabledInfo:
            return AISettingsSection.enabled.rawValue
        case .providerHeader, .provider:
            return AISettingsSection.provider.rawValue
        case .apiKeyHeader, .apiKey, .apiKeyInfo:
            return AISettingsSection.apiKey.rawValue
        case .endpointHeader, .baseURL, .model, .fetchModels, .endpointInfo:
            return AISettingsSection.endpoint.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .enabled:
            return 0
        case .enabledInfo:
            return 1
        case .providerHeader:
            return 2
        case .provider:
            return 3
        case .apiKeyHeader:
            return 4
        case .apiKey:
            return 5
        case .apiKeyInfo:
            return 6
        case .endpointHeader:
            return 7
        case .baseURL:
            return 8
        case .model:
            return 9
        case .fetchModels:
            return 10
        case .endpointInfo:
            return 11
        }
    }

    static func <(lhs: AISettingsEntry, rhs: AISettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! AISettingsControllerArguments
        switch self {
        case let .enabled(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateEnabled(value)
            })
        case let .enabledInfo(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .providerHeader(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .provider(_, text, value):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: text, label: value.displayName, sectionId: self.section, style: .blocks, action: {
                arguments.selectProvider()
            })
        case let .apiKeyHeader(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .apiKey(_, placeholder, text):
            return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(string: ""), text: text, placeholder: placeholder, type: .password, sectionId: self.section, textUpdated: { value in
                arguments.updateAPIKey(value)
            }, action: {})
        case let .apiKeyInfo(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .endpointHeader(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .baseURL(_, placeholder, text):
            return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(string: "Base URL", attributes: [.font: Font.regular(presentationData.fontSize.itemListBaseFontSize), .foregroundColor: presentationData.theme.list.itemPrimaryTextColor]), text: text, placeholder: placeholder, type: .regular(capitalization: false, autocorrection: false), alignment: .right, spacing: 16.0, sectionId: self.section, textUpdated: { value in
                arguments.updateBaseURL(value)
            }, action: {})
        case let .model(_, currentModel, _):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: "Model", label: currentModel, sectionId: self.section, style: .blocks, action: {
                arguments.selectModel()
            })
        case let .fetchModels(_, isLoading):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: isLoading ? "Fetching Models..." : "Fetch Available Models", kind: isLoading ? .disabled : .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.fetchModels()
            })
        case let .endpointInfo(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private struct AISettingsControllerState: Equatable {
    var configuration: AIConfiguration
    var isFetchingModels: Bool = false
    var fetchedModels: [(id: String, name: String)] = []
    
    static func == (lhs: AISettingsControllerState, rhs: AISettingsControllerState) -> Bool {
        return lhs.configuration == rhs.configuration &&
               lhs.isFetchingModels == rhs.isFetchingModels &&
               lhs.fetchedModels.map { $0.id } == rhs.fetchedModels.map { $0.id }
    }
}

private func aiSettingsControllerEntries(
    presentationData: PresentationData,
    state: AISettingsControllerState
) -> [AISettingsEntry] {
    var entries: [AISettingsEntry] = []

    // Enable section
    entries.append(.enabled(presentationData.theme, "Enable AI Assistant", state.configuration.enabled))
    entries.append(.enabledInfo(presentationData.theme, "Enable AI-powered features like chat summaries."))

    // Provider section
    entries.append(.providerHeader(presentationData.theme, "PROVIDER"))
    entries.append(.provider(presentationData.theme, "AI Provider", state.configuration.provider))

    // API Key section
    entries.append(.apiKeyHeader(presentationData.theme, "API KEY"))
    entries.append(.apiKey(presentationData.theme, "Enter your API key", state.configuration.apiKey))
    
    let apiKeyHint: String
    switch state.configuration.provider {
    case .openai:
        apiKeyHint = "Get your API key from platform.openai.com"
    case .anthropic:
        apiKeyHint = "Get your API key from console.anthropic.com"
    case .custom:
        apiKeyHint = "Enter the API key for your custom endpoint"
    }
    entries.append(.apiKeyInfo(presentationData.theme, apiKeyHint))

    // Endpoint section
    entries.append(.endpointHeader(presentationData.theme, "ENDPOINT"))
    entries.append(.baseURL(presentationData.theme, state.configuration.provider.defaultEndpoint, state.configuration.baseURL))
    entries.append(.model(presentationData.theme, state.configuration.model, state.configuration.provider))
    entries.append(.fetchModels(presentationData.theme, state.isFetchingModels))
    entries.append(.endpointInfo(presentationData.theme, "Customize the API endpoint and model if needed. Tap 'Fetch Available Models' to get the model list from the server."))

    return entries
}

public func aiSettingsController(context: AccountContext) -> ViewController {
    let statePromise = ValuePromise(AISettingsControllerState(
        configuration: AIConfigurationStorage.shared.getConfiguration()
    ), ignoreRepeated: true)
    let stateValue = Atomic(value: AISettingsControllerState(
        configuration: AIConfigurationStorage.shared.getConfiguration()
    ))
    let updateState: ((AISettingsControllerState) -> AISettingsControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }

    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?

    let arguments = AISettingsControllerArguments(
        context: context,
        updateEnabled: { value in
            updateState { state in
                var state = state
                state.configuration.enabled = value
                AIConfigurationStorage.shared.saveConfiguration(state.configuration)
                return state
            }
        },
        updateProvider: { value in
            updateState { state in
                var state = state
                state.configuration.provider = value
                state.configuration.baseURL = value.defaultEndpoint
                state.configuration.model = value.defaultModel
                AIConfigurationStorage.shared.saveConfiguration(state.configuration)
                return state
            }
        },
        updateAPIKey: { value in
            updateState { state in
                var state = state
                state.configuration.apiKey = value
                AIConfigurationStorage.shared.saveConfiguration(state.configuration)
                return state
            }
        },
        updateBaseURL: { value in
            updateState { state in
                var state = state
                state.configuration.baseURL = value
                AIConfigurationStorage.shared.saveConfiguration(state.configuration)
                return state
            }
        },
        updateModel: { value in
            updateState { state in
                var state = state
                state.configuration.model = value
                AIConfigurationStorage.shared.saveConfiguration(state.configuration)
                return state
            }
        },
        selectProvider: {
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let actionSheet = ActionSheetController(presentationData: presentationData)

            var items: [ActionSheetItem] = []
            for provider in AIProvider.allCases {
                items.append(ActionSheetButtonItem(title: provider.displayName, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    updateState { state in
                        var state = state
                        state.configuration.provider = provider
                        state.configuration.baseURL = provider.defaultEndpoint
                        state.configuration.model = provider.defaultModel
                        AIConfigurationStorage.shared.saveConfiguration(state.configuration)
                        return state
                    }
                }))
            }

            actionSheet.setItemGroups([
                ActionSheetItemGroup(items: items),
                ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                    })
                ])
            ])

            presentControllerImpl?(actionSheet, nil)
        },
        selectModel: {
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let currentState = stateValue.with { $0 }

            // Use fetched models if available, otherwise fall back to defaults
            var models: [(id: String, name: String)]
            if !currentState.fetchedModels.isEmpty {
                models = currentState.fetchedModels
            } else {
                switch currentState.configuration.provider {
                case .anthropic:
                    models = [
                        ("claude-sonnet-4-5-20250929", "Claude Sonnet 4.5"),
                        ("claude-opus-4-5-20251101", "Claude Opus 4.5"),
                        ("claude-haiku-4-5-20251001", "Claude Haiku 4.5")
                    ]
                case .openai:
                    models = [
                        ("gpt-4o-mini", "GPT-4o Mini"),
                        ("gpt-4o", "GPT-4o"),
                        ("gpt-4-turbo", "GPT-4 Turbo"),
                        ("gpt-3.5-turbo", "GPT-3.5 Turbo")
                    ]
                case .custom:
                    models = []
                }
            }

            // Use searchable list for many models, ActionSheet for few
            if models.count > 10 {
                // Use SearchableSelectionScreen with search
                let items = models.map { SearchableSelectionItem(id: $0.id, title: $0.name) }
                let configuration = SearchableSelectionConfiguration(
                    title: "Select Model",
                    searchPlaceholder: "Search models...",
                    emptyResultsText: "No models match your search",
                    showItemCount: true
                )
                let selectionController = searchableSelectionScreen(
                    context: context,
                    items: items,
                    selectedId: currentState.configuration.model,
                    configuration: configuration,
                    completion: { selectedId in
                        updateState { state in
                            var state = state
                            state.configuration.model = selectedId
                            AIConfigurationStorage.shared.saveConfiguration(state.configuration)
                            return state
                        }
                    }
                )
                pushControllerImpl?(selectionController)
            } else {
                // Use ActionSheet for small number of models
                let actionSheet = ActionSheetController(presentationData: presentationData)

                var items: [ActionSheetItem] = []
                for model in models {
                    items.append(ActionSheetButtonItem(title: model.name, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        updateState { state in
                            var state = state
                            state.configuration.model = model.id
                            AIConfigurationStorage.shared.saveConfiguration(state.configuration)
                            return state
                        }
                    }))
                }

                // Always allow custom model input
                items.append(ActionSheetButtonItem(title: "Enter Custom Model...", action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()

                    let promptVC = promptController(
                        context: context,
                        text: "Custom Model",
                        value: currentState.configuration.model,
                        placeholder: "Enter model identifier",
                        apply: { value in
                            if let text = value, !text.isEmpty {
                                updateState { state in
                                    var state = state
                                    state.configuration.model = text
                                    AIConfigurationStorage.shared.saveConfiguration(state.configuration)
                                    return state
                                }
                            }
                        }
                    )
                    presentControllerImpl?(promptVC, nil)
                }))

                actionSheet.setItemGroups([
                    ActionSheetItemGroup(items: items),
                    ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])
                ])

                presentControllerImpl?(actionSheet, nil)
            }
        },
        fetchModels: {
            let currentState = stateValue.with { $0 }
            
            // Check if API key and base URL are configured
            guard !currentState.configuration.apiKey.isEmpty && !currentState.configuration.baseURL.isEmpty else {
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                let alertController = textAlertController(
                    context: context,
                    title: "Configuration Required",
                    text: "Please enter your API key and base URL first.",
                    actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]
                )
                presentControllerImpl?(alertController, nil)
                return
            }
            
            // Set loading state
            updateState { state in
                var state = state
                state.isFetchingModels = true
                return state
            }
            
            // Fetch models
            let signal = AIService.fetchModels(
                baseURL: currentState.configuration.baseURL,
                apiKey: currentState.configuration.apiKey,
                provider: currentState.configuration.provider
            )
            
            let _ = (signal |> deliverOnMainQueue).start(next: { models in
                updateState { state in
                    var state = state
                    state.isFetchingModels = false
                    state.fetchedModels = models.map { ($0.id, $0.name) }
                    return state
                }
                
                if models.isEmpty {
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    let alertController = textAlertController(
                        context: context,
                        title: "No Models Found",
                        text: "No models were returned from the server. You can still enter a model name manually.",
                        actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]
                    )
                    presentControllerImpl?(alertController, nil)
                } else {
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    let alertController = textAlertController(
                        context: context,
                        title: "Models Fetched",
                        text: "Found \(models.count) models. Tap 'Model' to select one.",
                        actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]
                    )
                    presentControllerImpl?(alertController, nil)
                }
            }, error: { error in
                updateState { state in
                    var state = state
                    state.isFetchingModels = false
                    return state
                }
                
                let errorMessage: String
                switch error {
                case .invalidConfiguration:
                    errorMessage = "Invalid configuration. Please check your settings."
                case .networkError(let err):
                    errorMessage = "Network error: \(err.localizedDescription)"
                case .invalidResponse:
                    errorMessage = "Invalid response from server."
                case .apiError(let msg):
                    errorMessage = "API error: \(msg)"
                case .decodingError:
                    errorMessage = "Failed to parse server response."
                }
                
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                let alertController = textAlertController(
                    context: context,
                    title: "Failed to Fetch Models",
                    text: errorMessage,
                    actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]
                )
                presentControllerImpl?(alertController, nil)
            })
        }
    )

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        statePromise.get()
    )
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("AI Settings"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: aiSettingsControllerEntries(presentationData: presentationData, state: state), style: .blocks)

        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    
    presentControllerImpl = { [weak controller] c, a in
        controller?.present(c, in: .window(.root), with: a)
    }
    
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    
    return controller
}
