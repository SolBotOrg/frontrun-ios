import Foundation
import Display
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import PromptUI
import FRServices

private final class FRAISummarySettingsControllerArguments {
    let selectMessageCount: () -> Void
    let updateUserPrompt: (String) -> Void
    let resetUserPrompt: () -> Void

    init(
        selectMessageCount: @escaping () -> Void,
        updateUserPrompt: @escaping (String) -> Void,
        resetUserPrompt: @escaping () -> Void
    ) {
        self.selectMessageCount = selectMessageCount
        self.updateUserPrompt = updateUserPrompt
        self.resetUserPrompt = resetUserPrompt
    }
}

private enum FRAISummarySettingsSection: Int32 {
    case messageCount
    case userPrompt
}

private enum FRAISummarySettingsEntry: ItemListNodeEntry {
    case messageCountHeader(PresentationTheme, String)
    case messageCount(PresentationTheme, String, SummaryMessageCount)
    case messageCountInfo(PresentationTheme, String)

    case userPromptHeader(PresentationTheme, String)
    case userPrompt(PresentationTheme, String, String)
    case userPromptInfo(PresentationTheme, String)
    case resetUserPrompt(PresentationTheme, String)

    var section: ItemListSectionId {
        switch self {
        case .messageCountHeader, .messageCount, .messageCountInfo:
            return FRAISummarySettingsSection.messageCount.rawValue
        case .userPromptHeader, .userPrompt, .userPromptInfo, .resetUserPrompt:
            return FRAISummarySettingsSection.userPrompt.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .messageCountHeader:
            return 0
        case .messageCount:
            return 1
        case .messageCountInfo:
            return 2
        case .userPromptHeader:
            return 3
        case .userPrompt:
            return 4
        case .userPromptInfo:
            return 5
        case .resetUserPrompt:
            return 6
        }
    }

    static func <(lhs: FRAISummarySettingsEntry, rhs: FRAISummarySettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! FRAISummarySettingsControllerArguments
        switch self {
        case let .messageCountHeader(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .messageCount(_, text, value):
            return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value.displayName, sectionId: self.section, style: .blocks, action: {
                arguments.selectMessageCount()
            })
        case let .messageCountInfo(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .userPromptHeader(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .userPrompt(_, placeholder, text):
            return ItemListMultilineInputItem(presentationData: presentationData, text: text, placeholder: placeholder, maxLength: nil, sectionId: self.section, style: .blocks, minimalHeight: 80.0, textUpdated: { value in
                arguments.updateUserPrompt(value)
            })
        case let .userPromptInfo(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .resetUserPrompt(_, text):
            return ItemListActionItem(presentationData: presentationData, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.resetUserPrompt()
            })
        }
    }
}

private struct FRAISummarySettingsControllerState: Equatable {
    var configuration: AIConfiguration
}

private func frAISummarySettingsControllerEntries(
    presentationData: PresentationData,
    state: FRAISummarySettingsControllerState
) -> [FRAISummarySettingsEntry] {
    var entries: [FRAISummarySettingsEntry] = []

    // Message count section
    entries.append(.messageCountHeader(presentationData.theme, "MESSAGE COUNT"))
    entries.append(.messageCount(presentationData.theme, "Messages to Summarize", state.configuration.summaryMessageCount))
    entries.append(.messageCountInfo(presentationData.theme, "The number of recent messages to include (100-3000). Messages will be automatically truncated if they exceed the model's context limit."))

    // User Prompt section
    entries.append(.userPromptHeader(presentationData.theme, "CUSTOM PROMPT (OPTIONAL)"))
    entries.append(.userPrompt(presentationData.theme, "Additional instructions...", state.configuration.summaryUserPrompt))
    entries.append(.userPromptInfo(presentationData.theme, "Additional instructions that will be prepended to the messages. Custom prompts take higher priority and can customize the summary output."))
    entries.append(.resetUserPrompt(presentationData.theme, "Clear Custom Prompt"))

    return entries
}

public func aiSummarySettingsController(context: AccountContext) -> ViewController {
    let statePromise = ValuePromise(FRAISummarySettingsControllerState(
        configuration: AIConfigurationStorage.shared.getConfiguration()
    ), ignoreRepeated: true)
    let stateValue = Atomic(value: FRAISummarySettingsControllerState(
        configuration: AIConfigurationStorage.shared.getConfiguration()
    ))
    let updateState: ((FRAISummarySettingsControllerState) -> FRAISummarySettingsControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }

    var presentControllerImpl: ((ViewController, Any?) -> Void)?

    let arguments = FRAISummarySettingsControllerArguments(
        selectMessageCount: {
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let actionSheet = ActionSheetController(presentationData: presentationData)

            var items: [ActionSheetItem] = []
            for count in SummaryMessageCount.allCases {
                items.append(ActionSheetButtonItem(title: count.displayName, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    updateState { state in
                        var state = state
                        state.configuration.summaryMessageCount = count
                        AIConfigurationStorage.shared.saveConfiguration(state.configuration)
                        return state
                    }
                }))
            }

            // Add custom option
            items.append(ActionSheetButtonItem(title: "Custom...", action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()

                let currentValue = stateValue.with { $0 }.configuration.summaryMessageCount.value
                let promptVC = promptController(
                    context: context,
                    text: "Custom Message Count",
                    subtitle: "Enter the number of messages (100-3000):",
                    value: "\(currentValue)",
                    placeholder: "Enter number",
                    apply: { value in
                        if let text = value, let count = Int(text) {
                            let clampedCount = min(max(count, SummaryMessageCount.minValue), SummaryMessageCount.maxValue)
                            updateState { state in
                                var state = state
                                state.configuration.summaryMessageCount = .custom(clampedCount)
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
        },
        updateUserPrompt: { value in
            updateState { state in
                var state = state
                state.configuration.summaryUserPrompt = value
                AIConfigurationStorage.shared.saveConfiguration(state.configuration)
                return state
            }
        },
        resetUserPrompt: {
            updateState { state in
                var state = state
                state.configuration.summaryUserPrompt = ""
                AIConfigurationStorage.shared.saveConfiguration(state.configuration)
                return state
            }
        }
    )

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        statePromise.get()
    )
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Summary Settings"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: frAISummarySettingsControllerEntries(presentationData: presentationData, state: state), style: .blocks)

        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)

    presentControllerImpl = { [weak controller] c, a in
        controller?.present(c, in: .window(.root), with: a)
    }

    return controller
}
