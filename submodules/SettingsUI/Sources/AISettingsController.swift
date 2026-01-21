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
import AIModule

private final class AISettingsControllerArguments {
    let context: AccountContext
    let updateEnabled: (Bool) -> Void
    let updateProvider: (AIProvider) -> Void
    let updateAPIKey: (String) -> Void
    let updateBaseURL: (String) -> Void
    let updateModel: (String) -> Void
    let selectProvider: () -> Void

    init(
        context: AccountContext,
        updateEnabled: @escaping (Bool) -> Void,
        updateProvider: @escaping (AIProvider) -> Void,
        updateAPIKey: @escaping (String) -> Void,
        updateBaseURL: @escaping (String) -> Void,
        updateModel: @escaping (String) -> Void,
        selectProvider: @escaping () -> Void
    ) {
        self.context = context
        self.updateEnabled = updateEnabled
        self.updateProvider = updateProvider
        self.updateAPIKey = updateAPIKey
        self.updateBaseURL = updateBaseURL
        self.updateModel = updateModel
        self.selectProvider = selectProvider
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
    case model(PresentationTheme, String, String)
    case endpointInfo(PresentationTheme, String)

    var section: ItemListSectionId {
        switch self {
        case .enabled, .enabledInfo:
            return AISettingsSection.enabled.rawValue
        case .providerHeader, .provider:
            return AISettingsSection.provider.rawValue
        case .apiKeyHeader, .apiKey, .apiKeyInfo:
            return AISettingsSection.apiKey.rawValue
        case .endpointHeader, .baseURL, .model, .endpointInfo:
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
        case .endpointInfo:
            return 10
        }
    }

    static func <(lhs: AISettingsEntry, rhs: AISettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! AISettingsControllerArguments
        switch self {
        case let .enabled(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateEnabled(value)
            })
        case let .enabledInfo(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .providerHeader(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .provider(_, text, value):
            return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value.displayName, sectionId: self.section, style: .blocks, action: {
                arguments.selectProvider()
            })
        case let .apiKeyHeader(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .apiKey(_, placeholder, text):
            return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(string: ""), text: text, placeholder: placeholder, type: .password, sectionId: self.section, textUpdated: { value in
                arguments.updateAPIKey(value)
            }, action: {})
        case let .apiKeyInfo(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .endpointHeader(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .baseURL(_, placeholder, text):
            return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(string: "Base URL"), text: text, placeholder: placeholder, type: .regular(capitalization: false, autocorrection: false), sectionId: self.section, textUpdated: { value in
                arguments.updateBaseURL(value)
            }, action: {})
        case let .model(_, placeholder, text):
            return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(string: "Model"), text: text, placeholder: placeholder, type: .regular(capitalization: false, autocorrection: false), sectionId: self.section, textUpdated: { value in
                arguments.updateModel(value)
            }, action: {})
        case let .endpointInfo(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private struct AISettingsControllerState: Equatable {
    var configuration: AIConfiguration
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
    entries.append(.model(presentationData.theme, state.configuration.provider.defaultModel, state.configuration.model))
    entries.append(.endpointInfo(presentationData.theme, "Customize the API endpoint and model if needed."))

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
    
    return controller
}
